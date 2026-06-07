defmodule GymBro.TrainingTest do
  use GymBro.DataCase

  alias GymBro.Training

  import GymBro.AccountsFixtures
  import GymBro.ProgramsFixtures
  import GymBro.TrainingFixtures

  describe "workout sessions" do
    test "lists sessions for a user and finds the active one" do
      session = workout_session_fixture(%{status: "active", completed_at: nil})

      assert [fetched] = Training.list_workout_sessions_for_user(session.user_id)
      assert fetched.id == session.id
      assert Training.get_active_workout_session_for_user(session.user_id).id == session.id
    end

    test "lists completed sessions inside a date range" do
      inside = workout_session_fixture(%{completed_at: ~U[2026-05-08 10:30:00Z]})

      _outside =
        workout_session_fixture(%{user_id: inside.user_id, completed_at: ~U[2026-04-30 10:30:00Z]})

      assert [fetched] =
               Training.list_completed_workout_sessions_for_user_between(
                 inside.user_id,
                 ~D[2026-05-05],
                 ~D[2026-05-11]
               )

      assert fetched.id == inside.id
    end

    test "starts a workout once and reuses it when the same day is requested again" do
      user = user_fixture()
      workout_day = workout_day_fixture()

      Training.subscribe_to_client_session(user.id)

      assert {:ok, session} = Training.get_or_start_workout_session(user.id, workout_day.id)
      assert session.status == "active"
      assert_receive {:client_session_event, :session_started, payload}
      assert payload.session_id == session.id

      assert {:ok, resumed_session} =
               Training.get_or_start_workout_session(user.id, workout_day.id)

      assert resumed_session.id == session.id
    end

    test "broadcasts elapsed ticks for an active workout over pubsub" do
      session =
        workout_session_fixture(%{completed_at: nil, duration_seconds: nil, status: "active"})

      Training.subscribe_to_workout(session.id)

      assert :ok = Training.ensure_workout_clock(session.id, session.started_at)

      assert_receive {:workout_event, :elapsed_tick, payload}
      assert payload.started_at == session.started_at
      assert payload.elapsed_seconds >= 1

      assert :ok = Training.stop_workout_clock(session.id)
    end

    test "completes a workout and broadcasts the session completion" do
      session =
        workout_session_fixture(%{completed_at: nil, duration_seconds: nil, status: "active"})

      Training.subscribe_to_client_session(session.user_id)

      assert {:ok, completed_session} = Training.complete_workout_session(session)
      assert completed_session.status == "completed"

      assert_receive {:client_session_event, :session_completed, payload}
      assert payload.session_id == session.id
      assert payload.status == "completed"
    end
  end

  describe "exercise logs" do
    test "lists exercise logs for a session" do
      exercise_log = exercise_log_fixture()

      assert [fetched] = Training.list_exercise_logs_for_session(exercise_log.workout_session_id)
      assert fetched.id == exercise_log.id
    end

    test "logs sets and broadcasts them to the client session topic" do
      user = user_fixture()
      workout_day = workout_day_fixture()
      exercise = exercise_fixture(%{workout_day_id: workout_day.id})

      {:ok, session} =
        Training.create_workout_session(%{
          started_at: ~U[2026-05-10 09:00:00Z],
          status: "active",
          user_id: user.id,
          workout_day_id: workout_day.id
        })

      Training.subscribe_to_client_session(user.id)

      assert {:ok, log} =
               Training.log_exercise_set(session, exercise, %{
                 reps_completed: 10,
                 rpe: 8,
                 weight_kg: 24.0
               })

      assert log.set_number == 1

      assert_receive {:client_session_event, :set_logged, payload}
      assert payload.exercise_id == exercise.id
      assert payload.log.set_number == 1
    end

    test "recommends a slightly heavier load from the latest completed log" do
      user = user_fixture()
      workout_day = workout_day_fixture()

      exercise =
        exercise_fixture(%{name: "Bench Press", weight_kg: 24.0, workout_day_id: workout_day.id})

      {:ok, completed_session} =
        Training.create_workout_session(%{
          completed_at: ~U[2026-05-10 10:00:00Z],
          duration_seconds: 2_400,
          started_at: ~U[2026-05-10 09:20:00Z],
          status: "completed",
          user_id: user.id,
          workout_day_id: workout_day.id
        })

      assert {:ok, _log} =
               Training.log_exercise_set(completed_session, exercise, %{
                 reps_completed: 8,
                 weight_kg: 24.0
               })

      progressed_day =
        Training.apply_progression_recommendations_to_workout_day(user.id, workout_day)

      [progressed_exercise] = progressed_day.exercises

      assert progressed_exercise.last_logged_weight_kg == 24.0
      assert progressed_exercise.recommended_weight_kg == 26.5
      assert progressed_exercise.progression_hint =~ "Suggested next load 26.5 kg"
    end
  end
end
