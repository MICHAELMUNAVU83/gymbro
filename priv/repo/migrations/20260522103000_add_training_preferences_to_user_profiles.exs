defmodule GymBro.Repo.Migrations.AddTrainingPreferencesToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :preferred_rest_days, {:array, :integer}, default: []
      add :preferred_exercises_per_day, :integer
    end
  end
end
