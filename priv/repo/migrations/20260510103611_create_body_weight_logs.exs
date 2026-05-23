defmodule GymBro.Repo.Migrations.CreateBodyWeightLogs do
  use Ecto.Migration

  def change do
    create table(:body_weight_logs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :weight_kg, :float
      add :logged_at, :date
      add :notes, :string

      timestamps(type: :utc_datetime)
    end

    create index(:body_weight_logs, [:user_id])
  end
end
