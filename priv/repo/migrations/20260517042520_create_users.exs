defmodule Lazyparrot.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :telegram_id, :bigint, null: false
      add :telegram_username, :string
      add :telegram_first_name, :string
      add :telegram_last_name, :string
      add :telegram_language_code, :string
      add :telegram_is_premium, :boolean
      add :current_flow, :string
      add :current_flow_args, :map, default: %{}

      timestamps()
    end

    create unique_index(:users, [:telegram_id])
  end
end
