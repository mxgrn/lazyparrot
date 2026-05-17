defmodule Lazyparrot.Repo.Migrations.CreateCards do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add :front, :text, null: false
      add :back, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :state, :string, default: "learning"
      add :step, :integer, default: 0
      add :stability, :float
      add :difficulty, :float
      add :due, :utc_datetime, null: false
      add :last_review, :utc_datetime

      timestamps()
    end

    create index(:cards, [:user_id, :due])
  end
end
