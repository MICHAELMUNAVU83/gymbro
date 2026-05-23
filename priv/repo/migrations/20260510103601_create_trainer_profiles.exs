defmodule GymBro.Repo.Migrations.CreateTrainerProfiles do
  use Ecto.Migration

  def change do
    create table(:trainer_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :bio, :string
      add :specialization, :string
      add :years_experience, :integer
      add :certification, :string
      add :max_clients, :integer, null: false, default: 20

      timestamps(type: :utc_datetime)
    end

    create unique_index(:trainer_profiles, [:user_id])
  end
end
