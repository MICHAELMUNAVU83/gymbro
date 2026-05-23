defmodule GymBro.Repo.Migrations.CreatePrograms do
  use Ecto.Migration

  def change do
    create table(:programs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string
      add :description, :text
      add :total_weeks, :integer, null: false, default: 12
      add :current_week, :integer, null: false, default: 1
      add :current_phase, :integer, null: false, default: 1
      add :phase_name, :string
      add :status, :string, null: false, default: "active"
      add :source, :string, null: false, default: "ai"
      add :ai_raw_plan, :map

      timestamps(type: :utc_datetime)
    end

    create index(:programs, [:user_id])
    create index(:programs, [:created_by_id])
  end
end
