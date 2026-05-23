defmodule GymBro.Repo.Migrations.CreateTrainerClients do
  use Ecto.Migration

  def change do
    create table(:trainer_clients) do
      add :trainer_id, references(:users, on_delete: :delete_all), null: false
      add :client_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "active"
      add :notes, :string
      add :joined_at, :date

      timestamps(type: :utc_datetime)
    end

    create index(:trainer_clients, [:trainer_id])
    create index(:trainer_clients, [:client_id])
    create unique_index(:trainer_clients, [:trainer_id, :client_id])
  end
end
