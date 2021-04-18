#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkull.GameEngineTest do
  use ExUnit.Case, async: true
  import Support.AssertionHelpers
  alias NotSkull.Errors.GameError
  alias NotSkull.GameEngine
  alias NotSkull.GameEngine.Game
  alias Support.Factory

  @expected_phases_in_order [
    :joining,
    :choose_card,
    :guess_card,
    :reveal_and_score,
    :game_summary
  ]

  describe "new_game/0" do
    test "it returns a new game" do
      assert {:ok, %GameEngine.Game{id: new_game_id} = new_game} =
               GameEngine.new_game()

      assert is_uuid(new_game_id)

      expected_game = %NotSkull.GameEngine.Game{
        # current_player isn't chosen until game starts
        # new game should always be set to :joining
        current_phase: :joining,
        current_player_id: nil,
        id: new_game_id,
        players: []
      }

      assert new_game == expected_game
    end

    test "it accepts overrides for players" do
      expected_players = [player] = [Factory.struct_for(:player)]
      overrides = [players: expected_players]

      assert {:ok, %GameEngine.Game{id: new_game_id} = new_game} =
               GameEngine.new_game(overrides)

      expected_game = %NotSkull.GameEngine.Game{
        current_logging: expected_logging(:join, player),
        current_phase: :joining,
        current_player_id: nil,
        id: new_game_id,
        players: expected_players
      }

      assert new_game == expected_game
    end
  end

  describe "join/2" do
    test "success: it adds a player when game is unstarted" do
      existing_logging = ["I'm a test log."]

      new_game =
        Factory.struct_for(:new_game, %{current_logging: existing_logging})

      player = Factory.struct_for(:player)

      assert {:ok, updated_game} = GameEngine.join(new_game, player)

      expected_game = %{new_game | players: new_game.players ++ [player]}

      assert_values_for(
        expected: expected_game,
        actual: updated_game,
        fields:
          fields_for(expected_game) --
            [:current_logging, :players]
      )

      assert_unordered_lists_are_equal(
        expected: expected_game.players,
        actual: updated_game.players
      )

      expected_logging = existing_logging ++ expected_logging(:join, player)
      assert expected_logging == updated_game.current_logging
      refute_logs_rotated(new_game, updated_game)
    end

    test "error: returns error tuple when game is active" do
      active_game = Factory.struct_for(:new_game, %{active?: true})

      player = Factory.struct_for(:player)

      assert {:error, %GameError{message: message}} =
               GameEngine.join(active_game, player)

      assert message == "Player can't join: game is already in progress."
    end

    test "error: returns error if already 4 players" do
      expected_players = for _x <- 1..4, do: Factory.struct_for(:player)

      active_game =
        Factory.struct_for(:new_game, %{
          active?: false,
          players: expected_players
        })

      player = Factory.struct_for(:player)

      assert {:error, %GameError{message: message}} =
               GameEngine.join(active_game, player)

      assert message == "Player can't join: game already has max players."
    end
  end

  describe "start/2" do
    test "success: it starts the game when at least 2 players have joined" do
      existing_logging = ["I'm a test log."]

      expected_players =
        for _x <- 2..4, do: Factory.struct_for(:player, %{cards_in_hand: []})

      new_game =
        Factory.struct_for(:new_game, %{
          players: expected_players,
          current_logging: existing_logging
        })

      player_that_hit_start = Enum.random(expected_players)

      assert {:ok, %Game{} = returned_game} =
               GameEngine.start(new_game, player_that_hit_start)

      expected_game = %{new_game | active?: true, current_phase: :choose_card}

      assert_values_for(
        expected: expected_game,
        actual: returned_game,
        fields:
          fields_for(expected_game) --
            [:current_player_id, :logs, :current_logging, :players]
      )

      assert_unordered_lists_are_equal(
        expected: expected_players,
        actual: returned_game.players
      )

      [player_in_first_slot | _tl] = returned_game.players
      assert returned_game.current_player_id == player_in_first_slot.id

      assert expected_logging(:start, player_in_first_slot) ==
               returned_game.current_logging

      assert_logs_rotated(new_game, returned_game)
    end

    test "error: it returns error tuple when 'player that hit start' isn't in the game" do
      new_game =
        Factory.struct_for(:new_game, %{
          players: [Factory.struct_for(:player), Factory.struct_for(:player)]
        })

      assert {:error, %GameError{message: message}} =
               GameEngine.start(new_game, Factory.struct_for(:player))

      assert message == "Only players who have joined can start the game."
    end

    test "error: it returns and error tuple if there are fewer than 2 players" do
      player = Factory.struct_for(:player)
      new_game = Factory.struct_for(:new_game, %{players: [player]})

      assert {:error, %GameError{message: message}} =
               GameEngine.start(new_game, player)

      assert message ==
               "At least two players must have joined to start a game."
    end

    test "error: it returns and error tuple for an active game" do
      player = Factory.struct_for(:player)

      active_game =
        Factory.struct_for(:new_game, %{players: [player], active?: true})

      assert {:error, %GameError{message: message}} =
               GameEngine.start(active_game, player)

      assert message == "Game has already been started."
    end
  end

  describe "phases/0" do
    test "it returns phases in expected_order" do
      assert GameEngine.phases() == @expected_phases_in_order
    end
  end

  for current_phase <- @expected_phases_in_order do
    describe "update_game/2, common for all phases, #{current_phase}" do
      setup do
        # setup
        player_count = Enum.random(2..4)

        [first_player | _tail] =
          players =
          for _x <- 1..player_count,
              do: Factory.struct_for(:player, %{current_guess: nil})

        game =
          Factory.struct_for(:game, %{
            active?: true,
            current_phase: unquote(current_phase),
            current_player_id: first_player.id,
            players: players
          })

        move =
          Factory.struct_for(:move, %{
            player_id: game.current_player_id,
            phase: game.current_phase,
            value: Enum.random([:skull, :rose])
          })

        %{game: game, move: move}
      end

      test "error: returns error struct when game isn't active",
           %{game: game, move: move} do
        # setup
        invalid_game = %{game | active?: false}

        # exercise
        assert {:error, %GameError{message: message}} =
                 GameEngine.update_game(invalid_game, move)

        assert message == "The game is over or hasn't started."
      end

      test "error: returns error struct when move player isn't game's current player",
           %{game: game, move: move} do
        # setup
        [_first_player | [wrong_player | _remaining_players]] = game.players
        invalid_move = %{move | player_id: wrong_player.id}

        # exercise
        assert {:error, %GameError{message: message}} =
                 GameEngine.update_game(game, invalid_move)

        assert message == "It is not your turn."
      end

      test "error: returns error struct when game and move phase don't match",
           %{game: game, move: move} do
        # setup
        for move_phase <- @expected_phases_in_order,
            move_phase != game.current_phase do
          invalid_move = %{move | phase: move_phase}

          # exercise
          assert {:error, %GameError{message: message}} =
                   GameEngine.update_game(game, invalid_move)

          assert message == "Turn is out of order."
        end
      end
    end
  end

  describe "update_game/2, phase: :choose_card" do
    test "success: it updates the game with valid move" do
      # setup
      player_count = Enum.random(3..4)

      [chooser | [expected_first_guesser | _remaining_players]] =
        players = for _x <- 1..player_count, do: Factory.struct_for(:player)

      game =
        Factory.struct_for(:game, %{
          active?: true,
          current_phase: :choose_card,
          current_player_id: chooser.id,
          current_logging: expected_logging(:start, chooser),
          players: players
        })

      move =
        Factory.struct_for(:move, %{
          player_id: game.current_player_id,
          phase: game.current_phase,
          value: Enum.random([:skull, :rose])
        })

      # exercise
      assert {:ok, updated_game} = GameEngine.update_game(game, move)

      # assert
      [_chooser | [expected_next_player | _remaining_players]] = game.players

      assert updated_game.current_player_id == expected_next_player.id

      assert updated_game.current_card == move.value
      assert updated_game.current_phase == :guess_card

      assert expected_logging(:choose_card, chooser, expected_first_guesser) ==
               updated_game.current_logging

      assert_logs_rotated(game, updated_game)
    end
  end

  describe "update_game, phase: :guess_card" do
    setup do
      # setup
      [chooser | [first_guesser | _remaining_players]] =
        players =
        for _x <- 1..4, do: Factory.struct_for(:player, %{current_guess: nil})

      game =
        Factory.struct_for(:game, %{
          active?: true,
          current_card: Enum.random([:skull, :rose]),
          current_phase: :guess_card,
          current_player_id: first_guesser.id,
          players: players
        })

      move =
        Factory.struct_for(:move, %{
          player_id: game.current_player_id,
          phase: :guess_card,
          value: Enum.random([:skull, :rose])
        })

      %{
        game: game,
        move: move,
        chooser: chooser,
        first_guesser: first_guesser
      }
    end

    test "success: first guessing player: it updates the game and player", %{
      game: game,
      move: move,
      chooser: chooser,
      first_guesser: first_guesser
    } do
      game = %{
        game
        | current_logging:
            expected_logging(:choose_card, chooser, first_guesser)
      }

      # exercise
      assert {:ok, updated_game} = GameEngine.update_game(game, move)

      # assert
      # the move submitted was the 2nd player's, so the 3rd should be next
      expected_next_player = Enum.at(game.players, 2)
      assert updated_game.current_player_id == expected_next_player.id

      # current card is the one that the first player chose and will stay the
      # same for the round
      assert updated_game.current_card == game.current_card
      assert updated_game.current_phase == :guess_card

      # need to make sure the second player's guess was updated
      updated_first_guesser =
        Enum.find(updated_game.players, fn player ->
          player.id == move.player_id
        end)

      assert updated_first_guesser.current_guess == move.value

      assert updated_game.current_logging ==
               expected_logging(
                 :guess_card,
                 updated_first_guesser,
                 expected_next_player
               )

      assert_logs_rotated(game, updated_game)
    end

    test "success: last guessing player: it updates the game and player", %{
      game: game,
      move: move
    } do
      # move is by last player, will just update move from setup

      [chooser, _, _, last_guesser] = game.players
      move = %{move | player_id: last_guesser.id}

      # simulate second and third players having picked a card
      updated_players =
        game.players
        |> List.update_at(1, fn player ->
          %{player | current_guess: Enum.random([:skull, :rose])}
        end)
        |> List.update_at(2, fn player ->
          %{player | current_guess: Enum.random([:skull, :rose])}
        end)

      # logging isn't exactly right, but we just need existing logging.
      game = %{
        game
        | players: updated_players,
          current_player_id: last_guesser.id,
          current_logging:
            expected_logging(
              :choose_card,
              Factory.struct_for(:player),
              last_guesser
            )
      }

      # exercise
      assert {:ok, updated_game} = GameEngine.update_game(game, move)

      # assert
      # the move is from the last player, so the first should be next
      expected_next_player = Enum.at(game.players, 0)
      assert updated_game.current_player_id == expected_next_player.id

      # current card stays until it's reset in the reveal and score phase
      assert updated_game.current_card == game.current_card
      # since all players have guessed, game moves to the next phase
      assert updated_game.current_phase == :reveal_and_score

      # need to make sure the last player's guess was updated
      updated_last_guesser =
        Enum.find(updated_game.players, fn player ->
          player.id == move.player_id
        end)

      assert updated_last_guesser.current_guess == move.value

      assert updated_game.current_logging ==
               expected_logging(
                 :guess_card_last_guesser,
                 updated_last_guesser,
                 chooser
               )

      assert_logs_rotated(game, updated_game)
    end
  end

  describe "update_game, phase: :reveal_and_score" do
    setup do
      # setup
      [choosing_player | guessing_players] =
        players = [
          _chooser =
            Factory.struct_for(:player, %{current_guess: nil, score: 0}),
          _guesser =
            Factory.struct_for(
              :player,
              %{current_guess: Enum.random([:skull, :rose]), score: 0}
            ),
          _guesser =
            Factory.struct_for(
              :player,
              %{current_guess: Enum.random([:skull, :rose]), score: 0}
            ),
          _guesser =
            Factory.struct_for(
              :player,
              %{current_guess: Enum.random([:skull, :rose]), score: 0}
            )
        ]

      game =
        Factory.struct_for(:game, %{
          active?: true,
          current_card: Enum.random([:skull, :rose]),
          current_phase: :reveal_and_score,
          current_player_id: choosing_player.id,
          current_logging: ["test logging"],
          players: players
        })

      move =
        Factory.struct_for(:move, %{
          player_id: game.current_player_id,
          phase: :reveal_and_score,
          value: nil
        })

      %{
        game: game,
        move: move,
        choosing_player: choosing_player,
        guessing_players: guessing_players
      }
    end

    test "success: it updates the game, players, and their scores", context do
      %{
        game: game,
        move: move,
        choosing_player: choosing_player,
        guessing_players: guessing_players
      } = context

      # exercise
      assert {:ok, updated_game} = GameEngine.update_game(game, move)

      # verify guessing players
      [updated_choosing_player | updated_guessing_players] =
        updated_game.players

      expected_gessing_players =
        for player <- guessing_players do
          new_points =
            if player.current_guess == game.current_card, do: 1, else: 0

          %{player | score: player.score + new_points, current_guess: nil}
        end

      assert expected_gessing_players == updated_guessing_players

      # verify choosing player
      expected_score =
        Enum.reduce(expected_gessing_players, 3, fn player, acc ->
          acc - player.score
        end)

      assert updated_choosing_player.score == expected_score
      assert updated_choosing_player.current_guess == nil

      # verify game
      assert updated_game.current_phase == :choose_card

      expected_logs =
        expected_logging(
          :reveal_and_score,
          game,
          updated_game,
          choosing_player
        )

      assert updated_game.current_logging == expected_logs
      assert_logs_rotated(game, updated_game)
    end
  end

  defp expected_logging(:join, player) do
    ["#{player.name} has joined the game."]
  end

  defp expected_logging(:start, first_player) do
    ["The game has started.", "#{first_player.name} is choosing a card."]
  end

  defp expected_logging(:choose_card, chooser, next_player) do
    [
      "#{chooser.name} has chosen a card.",
      "#{next_player.name} is guessing a card."
    ]
  end

  defp expected_logging(:guess_card, guesser, next_guesser) do
    [
      "#{guesser.name} guessed #{guesser.current_guess}.",
      "#{next_guesser.name} is guessing a card."
    ]
  end

  defp expected_logging(:guess_card_last_guesser, guesser, chooser) do
    [
      "#{guesser.name} guessed #{guesser.current_guess}.",
      "#{chooser.name} can now reveal their card."
    ]
  end

  defp expected_logging(
         :reveal_and_score,
         original_game,
         updated_game,
         choosing_player
       ) do
    [updated_choosing_player | _updated_guessing_players] =
      updated_game.players

    Enum.zip(original_game.players, updated_game.players)
    |> Enum.map(fn {original_player, updated_player} ->
      if original_player.id == choosing_player.id do
        "#{original_player.name} chose #{original_game.current_card}."
      else
        "#{original_player.name} guessed #{original_player.current_guess} and scored #{
          updated_player.score
        } points."
      end
    end)
    # need to add the choosing player score summary as the last line
    |> List.insert_at(
      -1,
      "#{choosing_player.name} gained #{updated_choosing_player.score} points."
    )
  end

  defp assert_logs_rotated(original_game, updated_game) do
    for log_line <- original_game.current_logging do
      refute log_line in updated_game.current_logging,
             "Expected line `#{log_line}` to not be in current_logging."

      assert log_line in updated_game.logs,
             "Expected line `#{log_line}` to be in game log."
    end
  end

  defp refute_logs_rotated(original_game, updated_game) do
    for log_line <- original_game.current_logging do
      assert log_line in updated_game.current_logging,
             "Expected line `#{log_line}` to not be in current_logging."

      refute log_line in updated_game.logs,
             "Expected line `#{log_line}` to be in game log."
    end
  end
end
