defmodule GymBro.Repo.Migrations.AddPreferredBlockWeeksToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :preferred_block_weeks, :integer, null: false, default: 9
    end
  end
end
