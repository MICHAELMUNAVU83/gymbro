defmodule GymBro.Programs.WorkoutDay do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Programs.{Exercise, Program}

  schema "workout_days" do
    field :week_number, :integer
    field :day_number, :integer
    field :day_label, :string
    field :workout_type, :string
    field :estimated_duration_min, :integer
    field :muscle_groups, {:array, :string}
    field :is_rest_day, :boolean, default: false
    field :trainer_notes, :string
    belongs_to :program, Program
    has_many :exercises, Exercise

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout_day, attrs) do
    workout_day
    |> cast(attrs, [
      :program_id,
      :week_number,
      :day_number,
      :day_label,
      :workout_type,
      :estimated_duration_min,
      :muscle_groups,
      :is_rest_day,
      :trainer_notes
    ])
    |> validate_required([:program_id, :week_number, :day_number])
    |> validate_number(:week_number, greater_than: 0)
    |> validate_number(:day_number, greater_than: 0)
    |> validate_number(:estimated_duration_min, greater_than: 0)
    |> foreign_key_constraint(:program_id)
  end
end
