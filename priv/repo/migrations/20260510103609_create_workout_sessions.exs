defmodule GymBro.Repo.Migrations.CreateWorkoutSessions do
  use Ecto.Migration

  def change do
    create table(:workout_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :workout_day_id, references(:workout_days, on_delete: :delete_all), null: false
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :duration_seconds, :integer
      add :status, :string
      add :notes, :string
      add :trainer_feedback, :string

      timestamps(type: :utc_datetime)
    end

    create index(:workout_sessions, [:user_id])
    create index(:workout_sessions, [:workout_day_id])
  end
end
