#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkullWeb.Plugs.ValidateJWT do
  @moduledoc false
  alias NotSkull.JWTUtility

  def init(options) do
    options
  end

  def call(conn, _opts) do
    with {:ok, jwt} <- get_jwt_from_conn(conn),
          {:ok, user_id} <- JWTUtility.user_id_from_jwt(jwt) do
      conn = Plug.Conn.fetch_query_params(conn)

      updated_params = Map.merge(conn.params, %{"context_id" => user_id})
      %{conn | params: updated_params}
    else
      _ ->
        error =
          Jason.encode!(%{
            "errors" => [%{"message" => "Invalid token.", "field" => "token"}]
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, error)
        |> Plug.Conn.halt()
    end
  end

  defp get_jwt_from_conn(conn) do
    case :proplists.get_value("authorization", conn.req_headers) do
      "Bearer " <> jwt ->
        {:ok, jwt}

      _ ->
        {:erorr, :not_found}
    end
  end
end
