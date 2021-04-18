#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkullWeb.LobbyChannel do
  use NotSkullWeb, :channel

  alias NotSkull.GameEngine.Game

  @impl true
  def join("lobby:lobby", _payload, socket) do 
    {:ok, socket}
  end

  @spec broadcast_new_game(Game.t()) :: :ok | :error
  def broadcast_new_game(%Game{current_phase: :joining} = game) do
    NotSkullWeb.Endpoint.broadcast!("lobby:lobby", "new_game_created", %{ 
      game_id: game.id
    })
  end

  def broadcast_new_game(_) do
    :error
  end
end
