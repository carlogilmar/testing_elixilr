#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkull.GameEngine do
  alias NotSkull.Errors.GameError

  @callback update_game(Game.t(), Move.t()) ::
              {:ok, Game.t()} | {:error, GameError.t()}

  def phases do
    [
      :joining,
      :choose_card,
      :guess_card,
      :reveal_and_score,
      :game_summary
    ]
  end

  defmodule Game do
    @type t :: %__MODULE__{}
    defstruct active?: false,
              current_card: nil,
              current_logging: [],
              current_phase: nil,
              current_player_id: nil,
              id: nil,
              logs: [],
              players: []
  end

  defmodule Player do
    @type t :: %__MODULE__{}
    defstruct current_guess: nil,
              name: nil,
              id: nil,
              score: 0
  end

  defmodule Move do
    @type t :: %__MODULE__{}
    defstruct player_id: nil,
              phase: nil,
              value: nil
  end

  def new_game(overrides \\ []) do
    overridable = [:players]

    overrides_as_map =
      for {key, value} <- overrides,
          key in overridable,
          into: %{},
          do: {key, value}

    game =
      %NotSkull.GameEngine.Game{
        current_phase: :joining,
        id: Ecto.UUID.generate()
      }
      |> Map.merge(overrides_as_map)

    new_logging =
      for player <- game.players do
        "#{player.name} has joined the game."
      end

    {:ok, %{game | current_logging: new_logging}}
  end

  def join(%Game{active?: true}, _) do
    {:error,
     GameError.exception(
       message: "Player can't join: game is already in progress."
     )}
  end

  def join(%Game{players: players}, _) when length(players) >= 4 do
    {:error,
     GameError.exception(
       message: "Player can't join: game already has max players."
     )}
  end

  def join(%Game{} = game, %Player{} = player) do
    new_logging = ["#{player.name} has joined the game."]

    {:ok,
     %{
       game
       | players: game.players ++ [player],
         current_logging: game.current_logging ++ new_logging
     }}
  end

  def start(%Game{active?: true}, _) do
    {:error, GameError.exception(message: "Game has already been started.")}
  end

  def start(%Game{players: players}, _) when length(players) < 2 do
    {:error,
     GameError.exception(
       message: "At least two players must have joined to start a game."
     )}
  end

  def start(%Game{active?: false} = game, %Player{} = player_that_hit_start) do
    joined_player_ids = for player <- game.players, do: player.id

    result =
      if player_that_hit_start.id in joined_player_ids do
        players_with_cards_and_in_new_order = Enum.shuffle(game.players)

        first_player = hd(players_with_cards_and_in_new_order)

        new_logging = [
          "The game has started.",
          "#{first_player.name} is choosing a card."
        ]

        started_game = %{
          game
          | active?: true,
            current_phase: :choose_card,
            current_player_id: first_player.id,
            logs: game.current_logging,
            current_logging: new_logging,
            players: players_with_cards_and_in_new_order
        }

        {:ok, started_game}
      else
        {:error,
         GameError.exception(
           message: "Only players who have joined can start the game."
         )}
      end

    result
  end

  def update_game(%Game{} = game, %Move{} = move) do
    with {true, _} <- {game.active?, :active},
         {true, _} <- {game.current_player_id == move.player_id, :player},
         {true, _} <- {game.current_phase == move.phase, :phase} do
      updated_game =
        game
        |> rotate_logs(move)
        |> update_players(move)
        |> update_current_card(move)
        |> update_current_player(move)
        |> update_current_phase()

      {:ok, updated_game}
    else
      {_, :active} ->
        {:error, %GameError{message: "The game is over or hasn't started."}}

      {_, :player} ->
        {:error, %GameError{message: "It is not your turn."}}

      {_, :phase} ->
        {:error, %GameError{message: "Turn is out of order."}}
    end
  end

  defp rotate_logs(%Game{} = game, %Move{phase: phase})
       when phase in [:choose_card, :guess_card, :reveal_and_score] do
    %{game | logs: game.logs ++ game.current_logging, current_logging: []}
  end

  defp rotate_logs(game, _move) do
    game
  end

  defp update_current_card(%Game{} = game, %Move{
         phase: :choose_card,
         player_id: player_id,
         value: value
       }) do
    player = Enum.find(game.players, &(&1.id == player_id))
    new_logging = ["#{player.name} has chosen a card."]

    %{
      game
      | current_card: value,
        current_logging: game.current_logging ++ new_logging
    }
  end

  defp update_current_card(%Game{} = game, %Move{
         phase: :guess_card
       }) do
    game
  end

  defp update_current_card(%Game{} = game, %Move{
         phase: :reveal_and_score
       }) do
    game
  end

  defp update_current_player(
         %Game{} = game,
         %Move{phase: :choose_card} = move
       ) do
    next_player = next_player(game, move.player_id)
    new_logging = ["#{next_player.name} is guessing a card."]

    %{
      game
      | current_player_id: next_player.id,
        current_logging: game.current_logging ++ new_logging
    }
  end

  defp update_current_player(
         %Game{} = game,
         %Move{phase: :guess_card} = move
       ) do
    next_player = next_player(game, move.player_id)
    # total player count minus the chooser
    total_guess_count = Enum.count(game.players) - 1

    current_guess_count =
      Enum.count(game.players, &(not is_nil(&1.current_guess)))

    new_logging =
      if current_guess_count < total_guess_count do
        ["#{next_player.name} is guessing a card."]
      else
        ["#{next_player.name} can now reveal their card."]
      end

    %{
      game
      | current_player_id: next_player.id,
        current_logging: game.current_logging ++ new_logging
    }
  end

  defp update_current_player(%Game{} = game, %Move{} = move) do
    next_player = next_player(game, move.player_id)
    %{game | current_player_id: next_player.id}
  end

  defp update_current_phase(%Game{current_phase: :choose_card} = game) do
    %{game | current_phase: :guess_card}
  end

  defp update_current_phase(%Game{current_phase: :reveal_and_score} = game) do
    %{game | current_phase: :choose_card}
  end

  defp update_current_phase(%Game{current_phase: :guess_card} = game) do
    players_still_needing_to_guess =
      Enum.filter(game.players, fn player ->
        is_nil(player.current_guess) && player.id != game.current_player_id
      end)

    if Enum.empty?(players_still_needing_to_guess) do
      %{game | current_phase: :reveal_and_score}
    else
      game
    end
  end

  defp update_players(%Game{current_phase: :choose_card} = game, %Move{}) do
    game
  end

  defp update_players(
         %Game{current_phase: :guess_card} = game,
         %Move{} = move
       ) do
    player_index =
      Enum.find_index(game.players, fn player ->
        player.id == move.player_id
      end)

    updated_players =
      List.update_at(game.players, player_index, fn player ->
        %{player | current_guess: move.value}
      end)

    moving_player = Enum.at(game.players, player_index)
    new_logging = ["#{moving_player.name} guessed #{move.value}."]

    %{
      game
      | players: updated_players,
        current_logging: game.current_logging ++ new_logging
    }
  end

  defp update_players(
         %Game{current_phase: :reveal_and_score} = game,
         %Move{}
       ) do
    current_player_id = game.current_player_id
    current_player = Enum.find(game.players, &(&1.id == current_player_id))
    chooser_logging_1 = ["#{current_player.name} chose #{game.current_card}."]

    accumulator = %{
      chooser_points: 0,
      chooser_index: nil,
      guesser_logging: [],
      players: game.players
    }

    %{
      chooser_points: new_points,
      chooser_index: chooser_index,
      guesser_logging: guesser_logging,
      players: updated_players
    } =
      game.players
      |> Enum.with_index()
      |> Enum.reduce(accumulator, fn
        {%Player{id: ^current_player_id}, index}, acc ->
          %{acc | chooser_index: index}

        {guessing_player, index}, acc ->
          {guesser_new_points, chooser_new_points} =
            if guessing_player.current_guess == game.current_card do
              {1, 0}
            else
              {0, 1}
            end

          updated_guessing_player = %{
            guessing_player
            | score: guessing_player.score + guesser_new_points,
              current_guess: nil
          }

          updated_players =
            List.update_at(acc.players, index, fn _ ->
              updated_guessing_player
            end)

          new_logging = [
            "#{guessing_player.name} guessed #{guessing_player.current_guess} and scored #{
              guesser_new_points
            } points."
          ]

          %{
            acc
            | players: updated_players,
              chooser_points: acc.chooser_points + chooser_new_points,
              guesser_logging: acc.guesser_logging ++ new_logging
          }
      end)

    chooser_logging_2 = [
      "#{current_player.name} gained #{new_points} points."
    ]

    new_logging = chooser_logging_1 ++ guesser_logging ++ chooser_logging_2
    # chooser's score hasn't been updated yet
    updated_players =
      List.update_at(updated_players, chooser_index, fn player ->
        %{player | score: player.score + new_points}
      end)

    %{
      game
      | players: updated_players,
        current_logging: game.current_logging ++ new_logging
    }
  end

  defp next_player(game, current_player_id) do
    current_player_index =
      Enum.find_index(game.players, fn player ->
        player.id == current_player_id
      end)

    if next_player = Enum.at(game.players, current_player_index + 1) do
      next_player
    else
      List.first(game.players)
    end
  end
end
