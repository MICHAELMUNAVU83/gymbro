defmodule GymBro.Repo.Migrations.CreateCheckinImages do
  use Ecto.Migration

  def change do
    create table(:checkin_images) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :image_url, :string
      add :image_type, :string
      add :logged_at, :date
      add :notes, :string
      add :visible_to_trainer, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:checkin_images, [:user_id])
  end
end
