#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkullWeb.GameLiveTest do
  use NotSkullWeb.LiveCase, async: false

  setup_all(context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(NotSkull.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(NotSkull.Repo, {:shared, self()})

    # user: is someone in the db
    [{:ok, user1}, {:ok, user2}] = for _i <- 1..2, do: Factory.insert(:user)

    # player: is an "instance" of a user specific to an single game
    player1 = %NotSkull.GameEngine.Player{
      name: user1.name,
      id: user1.id
    }

    # By the time a game live view is mounted,
    # the first player is already in the game.
    {:ok, game} = NotSkull.ActiveGames.new_game(players: [player1])

    Map.merge(context, %{users: [user1, user2], game_id: game.id})
  end

  describe "2 player game" do
    test "clean play-through", context do
      user1_conn = user1_mount_view(context)
      user2_conn = user2_mount_and_join(context)
      start_game(%{user1_conn: user1_conn, user2_conn: user2_conn})
    end

    defp user1_mount_view(%{users: [user1, user2], game_id: game_id}) do
      conn = conn_for_user(user1, game_id)
      {:ok, view, _html} = live(conn)

      assert render(view) =~ "Waiting for other players to join..."

      assert text_value_of_element(view, id_attribute("joined-#{user1.id}")) ==
               user1.name <> "*"

      refute has_element?(view, id_attribute("joined-#{user2.id}"))

      # make sure button to start game isn't present when only 1 player has joined
      refute has_element?(view, id_attribute("button-join"))

      conn
    end

    defp user2_mount_and_join(%{users: [user1, user2], game_id: game_id}) do
      conn = conn_for_user(user2, game_id)
      {:ok, view, _html} = live(conn)

      # asterisk won't be present since current user isn't user1
      assert text_value_of_element(view, id_attribute("joined-#{user1.id}")) ==
               user1.name

      refute has_element?(view, id_attribute("joined-#{user2.id}"))

      # assert join button is present, and rendered correctly
      assert text_value_of_element(view, id_attribute("button-join")) ==
               "join"

      # click join button
      view_after_join =
        view |> element(id_attribute("button-join")) |> render_click()

      assert text_value_of_element(
               view_after_join,
               id_attribute("joined-#{user1.id}")
             ) ==
               user1.name

      assert text_value_of_element(
               view_after_join,
               id_attribute("joined-#{user2.id}")
             ) ==
               user2.name <> "*"

      {:ok, view, _html} = live(conn)
      conn
    end

    defp start_game(%{user1_conn: user1_conn, user2_conn: user2_conn}) do
      [user1_view, user2_view] =
        all_views =
        for conn <- [user1_conn, user2_conn] do
          {:ok, view, _html} = live(conn)

          assert has_element?(
                   view,
                   id_attribute("button-start"),
                   "start game"
                 )

          view
        end

      # random_users_view = Enum.random(all_views)

      # random_users_view |> element(id_attribute("button-start")) |> render_click()
      # |> IO.inspect()
    end
  end

  defp conn_for_user(user, game_id) do
    conn_for_user =
      Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(),
        user_id: user.id
      )

    get(conn_for_user, "/game?game_id=#{game_id}")
  end
end
