defmodule GymBro.Repo.Migrations.CreatePersonalRecords do
  use Ecto.Migration

  def change do
    create table(:personal_records) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :exercise_name, :string
      add :weight_kg, :float
      add :reps, :integer
      add :achieved_at, :date

      timestamps(type: :utc_datetime)
    end

    create index(:personal_records, [:user_id])
  end
end
