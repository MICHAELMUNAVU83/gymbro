defmodule GymBro.Repo.Migrations.AddPreferredSessionMinutesToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :preferred_session_minutes, :integer
    end
  end
end
