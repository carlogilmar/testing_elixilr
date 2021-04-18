#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkullWeb.UserSocket do
  use Phoenix.Socket
  alias NotSkull.{Accounts, JWTUtility}
  require Logger

  channel "lobby:*", NotSkullWeb.LobbyChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    jwt = URI.decode_www_form(token)

    with {:ok, user_id} <- JWTUtility.user_id_from_jwt(jwt), 
         {:ok, _valid_user} <- Accounts.get_user_by_id(user_id) do 
      socket = assign(socket, :user_id, user_id) 
      {:ok, socket}
    else
      something_else ->
        Logger.warn(inspect(something_else))
        :error
    end
  end

  def connect(_, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}" 
end
