defmodule GymBro.Trainer.TrainerExerciseOverride do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User
  alias GymBro.Programs.Exercise

  schema "trainer_exercise_overrides" do
    field :active, :boolean, default: true
    field :sets, :integer
    field :weight_kg, :float
    field :reps, :string
    field :notes, :string
    belongs_to :trainer, User
    belongs_to :client, User
    belongs_to :exercise, Exercise

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(trainer_exercise_override, attrs) do
    trainer_exercise_override
    |> cast(attrs, [
      :trainer_id,
      :client_id,
      :exercise_id,
      :weight_kg,
      :sets,
      :reps,
      :notes,
      :active
    ])
    |> validate_required([:trainer_id, :client_id, :exercise_id])
    |> validate_number(:weight_kg, greater_than: 0.0)
    |> validate_number(:sets, greater_than: 0)
    |> foreign_key_constraint(:trainer_id)
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:exercise_id)
  end
end
