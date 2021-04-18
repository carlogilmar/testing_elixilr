#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkullWeb.LobbyChannelTest do
  use NotSkullWeb.ChannelCase
  alias NotSkullWeb.{LobbyChannel, UserSocket}

  describe "broadcast_new_game/1" do
    setup do
      user_id = Factory.uuid() 

      {:ok, _, socket} =
        UserSocket
        |> socket("user_socket:#{user_id}", %{user_id: user_id}) 
        |> subscribe_and_join(LobbyChannel, "lobby:lobby") 

      %{socket: socket}
    end

    test "success: returns :ok, sends broadcast when passed an open game" do  
      open_game = Factory.struct_for(:game, %{current_phase: :joining}) 

      assert :ok = LobbyChannel.broadcast_new_game(open_game) 

      assert_broadcast("new_game_created", broadcast_payload) 
      assert broadcast_payload == %{game_id: open_game.id} 

      assert Jason.encode!(broadcast_payload) 
    end

    for non_open_phase <- NotSkull.GameEngine.phases() -- [:joining] do
      test "error: returns error, does not broadcast when game phase is #{non_open_phase}" do
        current_phase = unquote(non_open_phase)
        open_game = Factory.struct_for(:game, %{current_phase: current_phase})

        assert :error = LobbyChannel.broadcast_new_game(open_game)

        refute_broadcast("new_game_created", _broadcast_payload)
      end
    end
  end
end
