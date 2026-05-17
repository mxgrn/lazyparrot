defmodule Lazyparrot.CachedTranslations.CachedTranslation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cached_translations" do
    field :key, :string
    field :locale, :string
    field :value, :string
    field :context, :string, default: "default"
    field :domain, :string, default: "default"
    field :key_hash, :binary, read_after_writes: true

    timestamps()
  end

  def changeset(translation, attrs) do
    translation
    |> cast(attrs, [:key, :locale, :value, :context, :domain])
    |> validate_required([:key, :locale, :value])
    |> unique_constraint([:locale, :key_hash, :context, :domain])
  end
end
