defmodule GymBro.Training.WorkoutSession do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User
  alias GymBro.Programs.WorkoutDay
  alias GymBro.Training.ExerciseLog

  @statuses ~w(active completed abandoned paused)

  schema "workout_sessions" do
    field :status, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :duration_seconds, :integer
    field :notes, :string
    field :trainer_feedback, :string
    belongs_to :user, User
    belongs_to :workout_day, WorkoutDay
    has_many :exercise_logs, ExerciseLog

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workout_session, attrs) do
    workout_session
    |> cast(attrs, [
      :user_id,
      :workout_day_id,
      :started_at,
      :completed_at,
      :duration_seconds,
      :status,
      :notes,
      :trainer_feedback
    ])
    |> validate_required([:user_id, :workout_day_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workout_day_id)
  end
end
