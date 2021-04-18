#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkullWeb.UserSocketTest do
  use NotSkullWeb.ChannelCase 
  alias NotSkullWeb.UserSocket

  describe "connect/3" do
    test "success: allows connection when passed a valid JWT for a real user" do
      {:ok, existing_user} = Factory.insert(:user)
      jwt = sign_jwt(existing_user.id)

      assert {:ok, socket} = connect(UserSocket, %{token: jwt}) 
      assert socket.assigns.user_id == existing_user.id 
      assert socket.id == "user_socket:#{existing_user.id}" 
    end

    @tag capture_log: true
    test "error: returns :error for an invalid JWT" do
      assert :error = connect(UserSocket, %{token: "bad_token"})
    end

    @tag capture_log: true
    test "error: returns :error if user doesn't exist" do
      jwt = sign_jwt(Factory.uuid())

      assert :error = connect(UserSocket, %{token: jwt})
    end

  end
end
