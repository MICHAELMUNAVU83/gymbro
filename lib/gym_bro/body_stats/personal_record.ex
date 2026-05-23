defmodule GymBro.BodyStats.PersonalRecord do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User

  schema "personal_records" do
    field :exercise_name, :string
    field :weight_kg, :float
    field :reps, :integer
    field :achieved_at, :date
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(personal_record, attrs) do
    personal_record
    |> cast(attrs, [:user_id, :exercise_name, :weight_kg, :reps, :achieved_at])
    |> validate_required([:user_id, :exercise_name, :weight_kg, :reps, :achieved_at])
    |> validate_number(:weight_kg, greater_than: 0.0)
    |> validate_number(:reps, greater_than: 0)
    |> foreign_key_constraint(:user_id)
  end
end
