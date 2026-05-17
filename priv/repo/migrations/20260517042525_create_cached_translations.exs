defmodule Lazyparrot.Repo.Migrations.CreateCachedTranslations do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto", ""

    create table(:cached_translations) do
      add :key, :text, null: false
      add :locale, :string, null: false
      add :value, :text, null: false
      add :context, :string, null: false, default: "default"
      add :domain, :string, null: false, default: "default"

      timestamps()
    end

    execute """
    ALTER TABLE cached_translations
    ADD COLUMN key_hash bytea GENERATED ALWAYS AS (digest(key, 'sha256')) STORED
    """, ""

    create unique_index(:cached_translations, [:locale, :key_hash, :context, :domain])
  end
end
