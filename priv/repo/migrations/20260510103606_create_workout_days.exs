defmodule GymBro.Repo.Migrations.CreateWorkoutDays do
  use Ecto.Migration

  def change do
    create table(:workout_days) do
      add :program_id, references(:programs, on_delete: :delete_all), null: false
      add :week_number, :integer
      add :day_number, :integer
      add :day_label, :string
      add :workout_type, :string
      add :estimated_duration_min, :integer
      add :muscle_groups, {:array, :string}
      add :is_rest_day, :boolean, null: false, default: false
      add :trainer_notes, :string

      timestamps(type: :utc_datetime)
    end

    create index(:workout_days, [:program_id])
  end
end
