#---
# Excerpted from "Testing Elixir",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit http://www.pragmaticprogrammer.com/titles/lmelixir for more book information.
#---
defmodule Support.Factory do
  alias NotSkull.Accounts.User
  alias NotSkull.GameEngine
  alias NotSkull.Repo

  def params(:user) do
    %{
      email: email(),
      name: first_name(),
      password: password()
    }
  end

  def set_password(user, password) do
    hashed_password = Argon2.hash_pwd_salt(password)
    %{user | password: hashed_password}
  end

  # DO NOT SORT THESE!
  @phases_in_order [
    :joining,
    :choose_card,
    :guess_card,
    :reveal_and_score,
    :game_summary
  ]

  def struct_for(:game) do
    player_count = Enum.random(2..4)
    players = for _x <- 1..player_count, do: struct_for(:player)

    %GameEngine.Game{
      current_phase: Enum.random(@phases_in_order),
      current_player_id: List.first(players).id,
      id: uuid(),
      players: players
    }
  end

  def struct_for(:player) do
    %GameEngine.Player{
      current_guess: Enum.random([nil, :skull, :rose]),
      id: uuid(),
      name: first_name(),
      score: 0
    }
  end

  def struct_for(:new_game) do
    struct_for(:game, %{
      id: uuid(),
      active?: false,
      current_card: nil,
      current_phase: :joining,
      current_player_id: nil,
      players: [],
    })
  end

  def struct_for(:move) do
    %GameEngine.Move{
      player_id: uuid(),
      phase: Enum.random(@phases_in_order)
    }
  end

  ### Inserts

  def insert(:user, overrides \\ %{}) do
    atom_params(:user, overrides)
    |> User.create_changeset()
    |> Repo.insert()
  end

  ### Utility Functions

  def struct_for(factory_name, overrides \\ %{})
      when is_atom(factory_name) and is_map(overrides) do
    Map.merge(struct_for(factory_name), overrides)
  end

  def string_params(factory_name, overrides \\ %{})
      when is_atom(factory_name) and is_map(overrides) do
    atom_params(factory_name, overrides)
    |> convert_atom_keys_to_strings()
  end

  def atom_params(factory_name, overrides \\ %{})
      when is_atom(factory_name) and is_map(overrides) do
    defaults = params(factory_name)
    Map.merge(defaults, overrides)
  end

  def build_one(%Ecto.Changeset{} = changeset) do
    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  def convert_atom_keys_to_strings(values) when is_list(values) do
    Enum.map(values, &convert_atom_keys_to_strings/1)
  end

  def convert_atom_keys_to_strings(%{__struct__: _} = record)
      when is_map(record) do
    Map.from_struct(record) |> convert_atom_keys_to_strings()
  end

  def convert_atom_keys_to_strings(record) when is_map(record) do
    Enum.reduce(record, Map.new(), fn {key, value}, acc ->
      Map.put(acc, to_string(key), convert_atom_keys_to_strings(value))
    end)
  end

  def convert_atom_keys_to_strings(value) do
    value
  end

  ### Data Generation
  def email, do: Faker.Internet.email()
  def first_name, do: Faker.Name.first_name()
  def uuid, do: Ecto.UUID.generate()
  def password, do: Faker.Lorem.characters(32) |> to_string
end
