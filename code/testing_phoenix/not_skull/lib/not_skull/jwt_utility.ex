#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkull.JWTUtility do
  require Logger

  def jwt_for_user(user_id) do
    algorithm = Application.fetch_env!(:not_skull, :jwt_algorithm)

    jwk =
      Application.fetch_env!(:not_skull, :secret_passphrase)
      |> Base.decode64!()
      |> JOSE.JWK.from_oct()

    claims = %{"cid" => user_id}
    headers = %{"alg" => algorithm}

    jwk
    |> JOSE.JWT.sign(headers, claims)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  def user_id_from_jwt(jwt) do
    passphrase = Application.fetch_env!(:not_skull, :secret_passphrase)
    algorithm = Application.fetch_env!(:not_skull, :jwt_algorithm)

    jwk = passphrase |> Base.decode64!() |> JOSE.JWK.from_oct()

    case JOSE.JWT.verify_strict(jwk, [algorithm], jwt) do
      {true, %{fields: %{"cid" => cid}}, _} ->
        {:ok, cid}

      {true, _wrong_content_jwt, _} ->
        {:error, :jwt_missing_user_id}

      _something_else ->
        {:error, :invalid_jwt}
    end
  end
end
