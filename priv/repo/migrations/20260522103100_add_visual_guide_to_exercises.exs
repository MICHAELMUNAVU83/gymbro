defmodule GymBro.Repo.Migrations.AddVisualGuideToExercises do
  use Ecto.Migration

  def change do
    alter table(:exercises) do
      add :visual_guide, :text
    end
  end
end
