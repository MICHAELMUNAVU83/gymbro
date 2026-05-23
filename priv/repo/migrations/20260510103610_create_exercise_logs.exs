defmodule GymBro.Repo.Migrations.CreateExerciseLogs do
  use Ecto.Migration

  def change do
    create table(:exercise_logs) do
      add :workout_session_id, references(:workout_sessions, on_delete: :delete_all), null: false
      add :exercise_id, references(:exercises, on_delete: :delete_all), null: false
      add :set_number, :integer
      add :reps_completed, :integer
      add :weight_kg, :float
      add :duration_seconds, :integer
      add :is_personal_record, :boolean, null: false, default: false
      add :rpe, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:exercise_logs, [:workout_session_id])
    create index(:exercise_logs, [:exercise_id])
  end
end
