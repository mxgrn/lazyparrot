defmodule Lazyparrot.Cards.Card do
  use Ecto.Schema
  import Ecto.Changeset

  alias Lazyparrot.Users.User

  schema "cards" do
    field :front, :string
    field :back, :string
    # Telegram file_ids; when set, the matching text field is the image caption
    field :front_image, :string
    field :back_image, :string
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
    |> cast(attrs, [
      :front,
      :back,
      :front_image,
      :back_image,
      :user_id,
      :state,
      :step,
      :stability,
      :difficulty,
      :due,
      :last_review
    ])
    |> validate_required([:user_id, :due])
    |> validate_side(:front, :front_image)
    |> validate_side(:back, :back_image)
  end

  @doc """
  The content of both card sides, in the shape `Lazyparrot.Cards.create/2` takes.
  """
  def sides(card) do
    Map.take(card, [:front, :back, :front_image, :back_image])
  end

  @doc """
  The sides of `card` swapped, for creating its reverse card.
  """
  def reverse_sides(card) do
    %{
      front: card.back,
      back: card.front,
      front_image: card.back_image,
      back_image: card.front_image
    }
  end

  # A side is either text, or an image with an optional caption.
  defp validate_side(changeset, text_field, image_field) do
    if get_field(changeset, text_field) || get_field(changeset, image_field) do
      changeset
    else
      add_error(changeset, text_field, "can't be blank")
    end
  end

  def fsrs_changeset(card, attrs) do
    card
    |> cast(attrs, [:state, :step, :stability, :difficulty, :due, :last_review])
  end
end
