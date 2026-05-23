defmodule GymBro.Training.ExerciseLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Programs.Exercise
  alias GymBro.Training.WorkoutSession

  schema "exercise_logs" do
    field :set_number, :integer
    field :reps_completed, :integer
    field :weight_kg, :float
    field :duration_seconds, :integer
    field :is_personal_record, :boolean, default: false
    field :rpe, :integer
    belongs_to :workout_session, WorkoutSession
    belongs_to :exercise, Exercise

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(exercise_log, attrs) do
    exercise_log
    |> cast(attrs, [
      :workout_session_id,
      :exercise_id,
      :set_number,
      :reps_completed,
      :weight_kg,
      :duration_seconds,
      :is_personal_record,
      :rpe
    ])
    |> validate_required([:workout_session_id, :exercise_id, :set_number])
    |> validate_number(:set_number, greater_than: 0)
    |> validate_number(:reps_completed, greater_than_or_equal_to: 0)
    |> validate_number(:weight_kg, greater_than: 0.0)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> validate_number(:rpe, greater_than: 0, less_than_or_equal_to: 10)
    |> foreign_key_constraint(:workout_session_id)
    |> foreign_key_constraint(:exercise_id)
  end
end
