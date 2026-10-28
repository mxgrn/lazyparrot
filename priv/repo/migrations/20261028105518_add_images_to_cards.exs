defmodule Lazyparrot.Repo.Migrations.AddImagesToCards do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      # Telegram file_ids; the matching text column then holds the (optional) caption
      add :front_image, :string
      add :back_image, :string
      modify :front, :text, null: true, from: {:text, null: false}
      modify :back, :text, null: true, from: {:text, null: false}
    end
  end
end
