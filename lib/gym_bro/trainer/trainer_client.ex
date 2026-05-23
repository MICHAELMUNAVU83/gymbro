defmodule GymBro.Trainer.TrainerClient do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User

  @statuses ~w(active paused discharged)

  schema "trainer_clients" do
    field :status, :string
    field :notes, :string
    field :joined_at, :date
    belongs_to :trainer, User
    belongs_to :client, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(trainer_client, attrs) do
    trainer_client
    |> cast(attrs, [:trainer_id, :client_id, :status, :notes, :joined_at])
    |> validate_required([:trainer_id, :client_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_distinct_client()
    |> foreign_key_constraint(:trainer_id)
    |> foreign_key_constraint(:client_id)
    |> unique_constraint([:trainer_id, :client_id])
  end

  defp validate_distinct_client(changeset) do
    if get_field(changeset, :trainer_id) == get_field(changeset, :client_id) do
      add_error(changeset, :client_id, "must be different from the trainer")
    else
      changeset
    end
  end
end
