defmodule GymBro.Profiles.TrainerProfile do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User

  @specializations ~w(strength fat_loss rehab general)

  schema "trainer_profiles" do
    field :bio, :string
    field :specialization, :string
    field :years_experience, :integer
    field :certification, :string
    field :max_clients, :integer, default: 20
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(trainer_profile, attrs) do
    trainer_profile
    |> cast(attrs, [
      :user_id,
      :bio,
      :specialization,
      :years_experience,
      :certification,
      :max_clients
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:specialization, @specializations)
    |> validate_number(:years_experience, greater_than_or_equal_to: 0)
    |> validate_number(:max_clients, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id)
  end
end
