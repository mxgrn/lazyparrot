defmodule Lazyparrot.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :telegram_id, :integer
    field :telegram_username, :string
    field :telegram_first_name, :string
    field :telegram_last_name, :string
    field :telegram_language_code, :string
    field :telegram_is_premium, :boolean
    field :current_flow, :string
    field :current_flow_args, :map, default: %{}

    has_many :cards, Lazyparrot.Cards.Card

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :telegram_id,
      :telegram_username,
      :telegram_first_name,
      :telegram_last_name,
      :telegram_language_code,
      :telegram_is_premium,
      :current_flow,
      :current_flow_args
    ])
    |> validate_required([:telegram_id])
    |> unique_constraint(:telegram_id)
  end
end
