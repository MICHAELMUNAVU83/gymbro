defmodule GymBro.TrainingFixtures do
  @moduledoc """
  Test helpers for the `GymBro.Training` context.
  """

  import GymBro.AccountsFixtures
  import GymBro.ProgramsFixtures

  def workout_session_fixture(attrs \\ %{}) do
    user = user_fixture()
    workout_day = workout_day_fixture()

    {:ok, workout_session} =
      attrs
      |> Enum.into(%{
        completed_at: ~U[2026-05-09 11:30:00Z],
        duration_seconds: 2_700,
        notes: "Felt strong throughout.",
        started_at: ~U[2026-05-09 10:45:00Z],
        status: "completed",
        trainer_feedback: "Nice progression.",
        user_id: user.id,
        workout_day_id: workout_day.id
      })
      |> GymBro.Training.create_workout_session()

    workout_session
  end

  def exercise_log_fixture(attrs \\ %{}) do
    workout_session = workout_session_fixture()
    exercise = exercise_fixture(%{workout_day_id: workout_session.workout_day_id})

    {:ok, exercise_log} =
      attrs
      |> Enum.into(%{
        duration_seconds: 90,
        exercise_id: exercise.id,
        is_personal_record: false,
        reps_completed: 10,
        rpe: 8,
        set_number: 1,
        weight_kg: 24.0,
        workout_session_id: workout_session.id
      })
      |> GymBro.Training.create_exercise_log()

    exercise_log
  end
end
