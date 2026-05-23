defmodule GymBro.Programs.Exercise do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Programs.WorkoutDay

  schema "exercises" do
    field :name, :string
    field :position, :integer
    field :sets, :integer
    field :reps, :string
    field :rest_seconds, :integer
    field :weight_kg, :float
    field :recommended_weight_kg, :float, virtual: true
    field :last_logged_weight_kg, :float, virtual: true
    field :progression_hint, :string, virtual: true
    field :notes, :string
    field :trainer_notes, :string
    field :visual_guide, :string
    field :is_timed, :boolean, default: false
    field :duration_seconds, :integer
    belongs_to :workout_day, WorkoutDay

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(exercise, attrs) do
    exercise
    |> cast(attrs, [
      :workout_day_id,
      :position,
      :name,
      :sets,
      :reps,
      :rest_seconds,
      :weight_kg,
      :notes,
      :trainer_notes,
      :visual_guide,
      :is_timed,
      :duration_seconds
    ])
    |> validate_required([:workout_day_id, :position, :name])
    |> validate_number(:position, greater_than: 0)
    |> validate_number(:sets, greater_than: 0)
    |> validate_number(:rest_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:weight_kg, greater_than: 0.0)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> foreign_key_constraint(:workout_day_id)
  end
end
