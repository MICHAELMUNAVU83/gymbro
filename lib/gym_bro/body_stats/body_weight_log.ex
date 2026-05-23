defmodule GymBro.BodyStats.BodyWeightLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User

  schema "body_weight_logs" do
    field :weight_kg, :float
    field :logged_at, :date
    field :notes, :string
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(body_weight_log, attrs) do
    body_weight_log
    |> cast(attrs, [:user_id, :weight_kg, :logged_at, :notes])
    |> validate_required([:user_id, :weight_kg, :logged_at])
    |> validate_number(:weight_kg, greater_than: 0.0)
    |> foreign_key_constraint(:user_id)
  end
end
