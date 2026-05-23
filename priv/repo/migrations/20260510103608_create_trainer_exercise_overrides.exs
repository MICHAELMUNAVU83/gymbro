defmodule GymBro.Repo.Migrations.CreateTrainerExerciseOverrides do
  use Ecto.Migration

  def change do
    create table(:trainer_exercise_overrides) do
      add :trainer_id, references(:users, on_delete: :delete_all), null: false
      add :client_id, references(:users, on_delete: :delete_all), null: false
      add :exercise_id, references(:exercises, on_delete: :delete_all), null: false
      add :weight_kg, :float
      add :sets, :integer
      add :reps, :string
      add :notes, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:trainer_exercise_overrides, [:trainer_id])
    create index(:trainer_exercise_overrides, [:client_id])
    create index(:trainer_exercise_overrides, [:exercise_id])
  end
end
