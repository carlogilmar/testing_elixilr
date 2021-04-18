#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule NotSkullWeb.Game do
  use Phoenix.LiveView
  use Phoenix.HTML
  alias NotSkull.{ActiveGames, GameEngine}
  alias NotSkull.Accounts
  alias NotSkullWeb.Router.Helpers, as: Routes

  # make these existing
  [:skull, :rose]

  defp topic(game_id) do
    "game-#{game_id}"
  end

  def mount(params, session, socket) do
    game_id = params["game_id"]
    user_id = session["user_id"]

    case ActiveGames.get_game_by_id(game_id) do
      {:error, %{message: _message}} ->
        {:ok, redirect(socket, to: Routes.user_path(socket, :show, user_id))}

      {:ok, game} ->
        player =
          Enum.find(game.players, fn player -> player.id == user_id end)

        NotSkullWeb.Endpoint.subscribe(topic(game_id))

        {:ok,
         assign(socket, %{
           user_id: user_id,
           game: game,
           user_player: player,
           page_title: "NotSkull - Game"
         })}
    end
  end

  def handle_event("join", _params, socket) do
    game = socket.assigns.game
    user_id = socket.assigns.user_id

    {updated_game, joined?, player, flash} =
      with false <- game.active?,
           {:ok, user} <- Accounts.get_user_by_id(user_id),
           player = %NotSkull.GameEngine.Player{name: user.name, id: user.id},
           {:ok, updated_game} = ActiveGames.join(game.id, player) do
        {updated_game, true, player, {:info, "You successfully joined."}}
      else
        _ ->
          {game, false, nil,
           {:error, "There was an issue and you couldn't join."}}
      end

    updated_socket =
      socket
      |> update_game(updated_game)
      |> assign_player(player)
      |> update_flash(flash)

    if joined? do
      NotSkullWeb.Endpoint.broadcast_from(
        self(),
        topic(game.id),
        "joined",
        %{}
      )
    end

    {:noreply, updated_socket}
  end

  def handle_event("start-game", _params, socket) do
    {game, player} = game_and_player(socket)

    updated_socket =
      case ActiveGames.start(game.id, player) do
        {:ok, updated_game} ->
          NotSkullWeb.Endpoint.broadcast_from(
            self(),
            topic(updated_game.id),
            "started",
            %{}
          )

          update_game(socket, updated_game)

        {:error, %{message: message}} ->
          update_flash(socket, {:error, message})
      end

    {:noreply, updated_socket}
  end

  def handle_event("card-chosen", %{"value" => value}, socket)
      when value in ["skull", "rose"] do
    {game, player} = game_and_player(socket)

    move = %GameEngine.Move{
      player_id: player.id,
      phase: game.current_phase,
      value: String.to_atom(value)
    }

    {:ok, game} = ActiveGames.move(game.id, move)

    NotSkullWeb.Endpoint.broadcast_from(
      self(),
      topic(game.id),
      "updated",
      %{}
    )

    socket = update_game(socket, game)
    {:noreply, socket}
  end

  def handle_event("reveal-and-score", _params, socket) do
    {game, player} = game_and_player(socket)

    move = %GameEngine.Move{
      player_id: player.id,
      phase: :reveal_and_score
    }

    {:ok, game} = ActiveGames.move(game.id, move)

    NotSkullWeb.Endpoint.broadcast_from(
      self(),
      topic(game.id),
      "updated",
      %{}
    )

    socket = update_game(socket, game)

    {:noreply, socket}
  end

  def handle_info(%{event: "joined"}, socket) do
    updated_socket =
      socket
      |> refresh_game()
      |> update_flash({:info, "A new player has joined."})

    {:noreply, updated_socket}
  end

  def handle_info(%{event: "started"}, socket) do
    updated_socket =
      socket
      |> refresh_game()
      |> update_flash({:info, "The game has started!"})

    {:noreply, updated_socket}
  end

  def handle_info(%{event: "updated", payload: _payload}, socket) do
    updated_socket =
      socket
      |> refresh_game()

    {:noreply, updated_socket}
  end

  def render(%{game: %{active?: false} = game} = assigns) do
    ~L"""
    <%= user_jwt_meta_tag(assigns[:user_id]) %>
    <div>
      <%= cond do %>
      <% is_nil(assigns.user_player) -> %>
        <button phx-click="join" id="button-join">join</button>
      <% Enum.count(game.players) > 1 -> %>
        <button phx-click="start-game" id="button-start">start game</button>
      <% true -> %>
        Waiting for other players to join...
      <% end %>

      <div id="players">
      Players:
        <ul id="player-list">
          <%= for player <- game.players do %>
            <li id=joined-<%= player.id %>><%= player.name %><%= if player.id == assigns.user_id, do: "*", else: "" %></li>
          <%end%>
        </ul>
      </div>
    </div>
    """
  end

  def render(assigns) do
    {game, user_player} = game_and_player(assigns)

    is_current_player? = user_player.id == game.current_player_id

    ~L"""
    <%= if is_current_player? do %>
      <h1>You are the current player</h1>
    <% else %>
      <h1> You are NOT current player</h1>
    <% end %>

    <div class="player-scores">
      <%= if game.active? do %>
        <%= for player <- game.players do %>
          <%= player.name %>: <%= player.score %>
        <% end %>
      <% end %>
    </div>

    <div class="container">
      <%= for log_line <- game.current_logging do %>
      <div class="row">
        <%= log_line %>
      </div>
      <% end %>
    </div>

    <%= player_view(
      assigns,
      game.current_phase,
      game.current_player_id,
      user_player,
      game
    ) %>
    """
  end

  def player_view(
        assigns,
        :choose_card,
        current_player_id,
        _user_player = %GameEngine.Player{id: current_player_id},
        _game
      ) do
    ~L"""
    <div class="container">
      <div class="row">
      choose a card
      </div>

      <div class="row">
        <button phx-click="card-chosen", value="skull">skull</button>
        <button phx-click="card-chosen", value="rose">rose</button>
      </div>
    </div>
    """
  end

  def player_view(
        assigns,
        :choose_card,
        _current_player_id,
        _user_player,
        _game
      ) do
    ~L"""
    I am in the generic choose_card view.
    """
  end

  def player_view(
        assigns,
        :guess_card,
        current_player_id,
        _user_player = %GameEngine.Player{id: current_player_id},
        _game
      ) do
    ~L"""
      <div class="container">
        <div class="row">
          guess a card
        </div>

        <div class="row">
          <button phx-click="card-chosen", value="skull">skull</button>
          <button phx-click="card-chosen", value="rose">rose</button>
        </div>
      </div>
    """
  end

  def player_view(
        assigns,
        :guess_card,
        _current_player_id,
        _user_player,
        _game
      ) do
    ~L"""
    I am in the generic guess_card view.
    """
  end

  def player_view(
        assigns,
        :reveal_and_score,
        current_player_id,
        _user_player = %GameEngine.Player{id: current_player_id},
        _game
      ) do
    ~L"""
    <div class="row">
      <button phx-click="reveal-and-score">reveal card and show scores</button>
    </div>
    """
  end

  def player_view(
        assigns,
        :reveal_and_score,
        _current_player_id,
        _user_player,
        _game
      ) do
    ~L"""
    I am in the generic reveal_and_score view.
    """
  end

  defp assign_player(socket, player) do
    assign(socket, %{user_player: player})
  end

  defp update_game(socket, game) do
    assign(socket, %{game: game})
  end

  defp update_flash(socket, {type, message}) do
    put_flash(socket, type, message)
  end

  defp game_and_player(%Phoenix.LiveView.Socket{} = socket) do
    {socket.assigns.game, socket.assigns.user_player}
  end

  defp game_and_player(assigns) do
    {assigns.game, assigns.user_player}
  end

  defp refresh_game(socket) do
    {:ok, updated_game} =
      NotSkull.ActiveGames.get_game_by_id(socket.assigns.game.id)

    assign(socket, game: updated_game)
  end

  defp user_jwt_meta_tag(user) do
    ~e"""
    <meta name="user-jwt" content="<%= NotSkull.JWTUtility.jwt_for_user(user) %>" />
    """
  end
end
