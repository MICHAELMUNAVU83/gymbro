defmodule GymBro.Repo.Migrations.CreateUserProfiles do
  use Ecto.Migration

  def change do
    create table(:user_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :age, :integer
      add :height_cm, :float
      add :weight_kg, :float
      add :goal_weight_kg, :float
      add :fitness_level, :string
      add :goal, :string
      add :days_per_week, :integer
      add :equipment, :string
      add :onboarding_complete, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_profiles, [:user_id])
  end
end
