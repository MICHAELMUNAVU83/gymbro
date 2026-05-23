defmodule GymBro.Repo.Migrations.CreateClientInvitations do
  use Ecto.Migration

  def change do
    create table(:client_invitations) do
      add :trainer_id, references(:users, on_delete: :delete_all), null: false
      add :email, :string, null: false
      add :token, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:client_invitations, [:trainer_id])
    create unique_index(:client_invitations, [:token])
  end
end
