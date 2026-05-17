defmodule Lazyparrot.Cards.Card do
  use Ecto.Schema
  import Ecto.Changeset

  alias Lazyparrot.Users.User

  schema "cards" do
    field :front, :string
    field :back, :string
    field :state, Ecto.Enum, values: [:learning, :review, :relearning], default: :learning
    field :step, :integer, default: 0
    field :stability, :float
    field :difficulty, :float
    field :due, :utc_datetime
    field :last_review, :utc_datetime

    belongs_to :user, User

    timestamps()
  end

  def changeset(card, attrs) do
    card
    |> cast(attrs, [:front, :back, :user_id, :state, :step, :stability, :difficulty, :due, :last_review])
    |> validate_required([:front, :back, :user_id, :due])
  end

  def fsrs_changeset(card, attrs) do
    card
    |> cast(attrs, [:state, :step, :stability, :difficulty, :due, :last_review])
  end
end
