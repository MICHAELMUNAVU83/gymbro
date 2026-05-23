defmodule GymBro.Trainer.ClientInvitation do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User

  @statuses ~w(pending accepted expired)

  schema "client_invitations" do
    field :status, :string
    field :token, :string
    field :email, :string
    field :expires_at, :utc_datetime
    belongs_to :trainer, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(client_invitation, attrs) do
    client_invitation
    |> cast(attrs, [:trainer_id, :email, :token, :status, :expires_at])
    |> validate_required([:trainer_id, :email, :token, :status])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:trainer_id)
    |> unique_constraint(:token)
  end
end
