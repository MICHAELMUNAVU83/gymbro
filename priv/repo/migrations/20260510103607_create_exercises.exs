defmodule GymBro.Repo.Migrations.CreateExercises do
  use Ecto.Migration

  def change do
    create table(:exercises) do
      add :workout_day_id, references(:workout_days, on_delete: :delete_all), null: false
      add :position, :integer
      add :name, :string
      add :sets, :integer
      add :reps, :string
      add :rest_seconds, :integer
      add :weight_kg, :float
      add :notes, :string
      add :trainer_notes, :string
      add :is_timed, :boolean, null: false, default: false
      add :duration_seconds, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:exercises, [:workout_day_id])
  end
end
