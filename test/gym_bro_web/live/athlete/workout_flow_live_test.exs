defmodule GymBroWeb.Athlete.WorkoutFlowLiveTest do
  use GymBroWeb.ConnCase, async: false

  import GymBro.AccountsFixtures
  import Phoenix.LiveViewTest

  alias GymBro.{Profiles, Programs, Trainer, Training}

  describe "athlete workout flow" do
    test "home, workouts, and body stats stay on live navigation", %{conn: conn} do
      %{user: user} = athlete_workout_fixture()
      conn = log_in_user(conn, user)

      {:ok, home_view, home_html} = live(conn, ~p"/home")

      assert home_html =~ "Athlete home"
      assert home_html =~ "Open workouts"
      assert home_html =~ "Workout calendar"
      assert home_html =~ "day streak"

      home_view
      |> element("nav[aria-label='Athlete'] a[href='/workouts']")
      |> render_click()

      assert_redirect(home_view, ~p"/workouts")

      {:ok, workouts_view, workouts_html} = live(conn, ~p"/workouts")

      assert workouts_html =~ "Workout flow"

      workouts_view
      |> element("nav[aria-label='Athlete'] a[href='/body-stats']")
      |> render_click()

      assert_redirect(workouts_view, ~p"/body-stats")
    end

    test "renders the workout list and opens a workout day", %{conn: conn} do
      %{
        exercise: exercise,
        second_week_exercise: second_week_exercise,
        second_week_workout_day: second_week_workout_day,
        user: user,
        workout_day: workout_day
      } = athlete_workout_fixture()

      conn = log_in_user(conn, user)

      {:ok, workouts_view, html} = live(conn, ~p"/workouts")

      assert html =~ "Workout flow"
      assert html =~ workout_day.day_label
      assert html =~ exercise.name
      assert html =~ "Week 2"
      refute html =~ second_week_exercise.name

      workouts_view
      |> element("button[phx-value-week='2']")
      |> render_click()

      assert render(workouts_view) =~ second_week_exercise.name
      assert render(workouts_view) =~ second_week_workout_day.day_label

      {:ok, view, detail_html} = live(conn, ~p"/workouts/#{workout_day.id}")

      assert detail_html =~ "Session control"
      assert detail_html =~ workout_day.day_label

      view
      |> element("#start-workout-button")
      |> render_click()

      session = Training.get_active_workout_session_for_user(user.id)
      assert_redirect(view, ~p"/workouts/session/#{session.id}")
    end

    test "logs sets in the active workout view and completes the workout", %{conn: conn} do
      %{exercise: exercise, user: user, workout_day: workout_day} = athlete_workout_fixture()

      {:ok, session} =
        Training.create_workout_session(%{
          started_at: ~U[2026-05-10 09:00:00Z],
          status: "active",
          user_id: user.id,
          workout_day_id: workout_day.id
        })

      Training.subscribe_to_client_session(user.id)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/workouts/session/#{session.id}")

      assert html =~ "LIVE"
      assert html =~ exercise.name

      view
      |> form("#set-log-form-#{exercise.id}", %{
        exercise_log: %{
          reps_completed: "10",
          weight_kg: "24.0"
        }
      })
      |> render_submit()

      assert_receive {:client_session_event, :set_logged, payload}
      assert payload.exercise_id == exercise.id
      assert render(view) =~ "Rest timer"

      assert [log] = Training.list_exercise_logs_for_session(session.id)
      assert log.reps_completed == 10

      view
      |> element("#complete-workout-button")
      |> render_click()

      assert_redirect(view, ~p"/workouts/#{workout_day.id}")
      assert Training.get_workout_session!(session.id).status == "completed"
    end

    test "updates the elapsed timer without a refresh", %{conn: conn} do
      %{user: user, workout_day: workout_day} = athlete_workout_fixture()

      started_at = DateTime.utc_now() |> DateTime.add(-61, :second) |> DateTime.truncate(:second)

      {:ok, session} =
        Training.create_workout_session(%{
          started_at: started_at,
          status: "active",
          user_id: user.id,
          workout_day_id: workout_day.id
        })

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/workouts/session/#{session.id}")

      assert html =~ "1m 01s"

      send(
        view.pid,
        {:workout_event, :elapsed_tick, %{elapsed_seconds: 62, started_at: started_at}}
      )

      assert render(view) =~ "1m 02s"
    end

    test "shows one expanded exercise at a time in the active workout view", %{conn: conn} do
      %{
        exercise: exercise,
        second_exercise: second_exercise,
        user: user,
        workout_day: workout_day
      } =
        athlete_workout_fixture()

      {:ok, session} =
        Training.create_workout_session(%{
          started_at: ~U[2026-05-10 09:00:00Z],
          status: "active",
          user_id: user.id,
          workout_day_id: workout_day.id
        })

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/workouts/session/#{session.id}")

      assert html =~ exercise.name
      assert html =~ second_exercise.name
      assert html =~ "Ready to start"
      assert has_element?(view, "#set-log-form-#{exercise.id}")
      refute has_element?(view, "#set-log-form-#{second_exercise.id}")
      refute has_element?(view, "#duration-#{exercise.id}")
      refute has_element?(view, "#rpe-#{exercise.id}")

      view
      |> element("#exercise-toggle-#{second_exercise.id}")
      |> render_click()

      assert has_element?(view, "#set-log-form-#{second_exercise.id}")
      refute has_element?(view, "#set-log-form-#{exercise.id}")
    end

    test "shows a suggested next load from the last completed session", %{conn: conn} do
      %{exercise: exercise, user: user, workout_day: workout_day} = athlete_workout_fixture()

      {:ok, completed_session} =
        Training.create_workout_session(%{
          completed_at: ~U[2026-05-09 10:00:00Z],
          duration_seconds: 2_400,
          started_at: ~U[2026-05-09 09:20:00Z],
          status: "completed",
          user_id: user.id,
          workout_day_id: workout_day.id
        })

      assert {:ok, _log} =
               Training.log_exercise_set(completed_session, exercise, %{
                 reps_completed: 8,
                 weight_kg: 24.0
               })

      {:ok, active_session} =
        Training.create_workout_session(%{
          started_at: ~U[2026-05-10 09:00:00Z],
          status: "active",
          user_id: user.id,
          workout_day_id: workout_day.id
        })

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/workouts/session/#{active_session.id}")

      assert html =~ "Suggested next load 26.5 kg"
      assert html =~ ~s(value="26.5")
    end

    test "shows a trainer message toast during an active workout", %{conn: conn} do
      %{user: user, workout_day: workout_day} = athlete_workout_fixture()
      trainer = trainer_user_with_profile()

      {:ok, _relationship} =
        Trainer.create_trainer_client(%{
          trainer_id: trainer.id,
          client_id: user.id,
          status: "active"
        })

      {:ok, session} =
        Training.create_workout_session(%{
          started_at: ~U[2026-05-10 09:00:00Z],
          status: "active",
          user_id: user.id,
          workout_day_id: workout_day.id
        })

      athlete_conn = log_in_user(conn, user)
      {:ok, athlete_view, athlete_html} = live(athlete_conn, ~p"/workouts/session/#{session.id}")

      assert athlete_html =~ "LIVE"

      trainer_conn = Phoenix.ConnTest.build_conn() |> log_in_user(trainer)
      {:ok, trainer_view, _trainer_html} = live(trainer_conn, ~p"/trainer/clients/#{user.id}")

      trainer_view
      |> form("#live-message-form", %{
        live_message: %{message: "Drive through your feet and keep the tempo clean."}
      })
      |> render_submit()

      assert_push_event(athlete_view, "workout:buzz", %{pattern: [100, 60, 100]})

      toast_html = render(athlete_view)

      assert toast_html =~ "Coach note"
      assert toast_html =~ "Drive through your feet and keep the tempo clean."
    end

    test "pushes a buzz event when the rest timer completes", %{conn: conn} do
      %{exercise: exercise, user: user, workout_day: workout_day} = athlete_workout_fixture()

      {:ok, session} =
        Training.create_workout_session(%{
          started_at: ~U[2026-05-10 09:00:00Z],
          status: "active",
          user_id: user.id,
          workout_day_id: workout_day.id
        })

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/workouts/session/#{session.id}")

      send(view.pid, {:workout_event, :rest_timer_completed, %{exercise_id: exercise.id}})

      assert_push_event(view, "workout:buzz", %{pattern: [180, 90, 180, 90, 260]})
      assert render(view) =~ "Rest timer complete."
    end
  end

  defp athlete_workout_fixture do
    user = user_fixture()

    {:ok, _profile} =
      Profiles.upsert_user_profile(user.id, %{
        age: 29,
        days_per_week: 4,
        equipment: "gym",
        fitness_level: "intermediate",
        goal: "muscle_gain",
        goal_weight_kg: 82.0,
        height_cm: 178.0,
        onboarding_complete: true,
        preferred_block_weeks: 9,
        weight_kg: 79.5
      })

    {:ok, program} =
      Programs.create_program(%{
        ai_raw_plan: %{},
        created_by_id: user.id,
        current_phase: 1,
        current_week: 1,
        description: "Strength block",
        name: "Build phase",
        phase_name: "Foundation",
        source: "ai",
        status: "active",
        total_weeks: 12,
        user_id: user.id
      })

    {:ok, workout_day} =
      Programs.create_workout_day(%{
        day_label: "Push",
        day_number: 1,
        estimated_duration_min: 55,
        is_rest_day: false,
        muscle_groups: ["chest", "shoulders"],
        program_id: program.id,
        trainer_notes: "Own every press.",
        week_number: 1,
        workout_type: "push"
      })

    {:ok, exercise} =
      Programs.create_exercise(%{
        name: "Incline Dumbbell Press",
        notes: "Control the eccentric.",
        position: 1,
        reps: "8-10",
        rest_seconds: 90,
        sets: 4,
        weight_kg: 24.0,
        workout_day_id: workout_day.id
      })

    {:ok, second_exercise} =
      Programs.create_exercise(%{
        name: "Chest Supported Row",
        notes: "Keep the chest locked into the pad.",
        position: 2,
        reps: "10-12",
        rest_seconds: 75,
        sets: 4,
        weight_kg: 30.0,
        workout_day_id: workout_day.id
      })

    {:ok, second_week_workout_day} =
      Programs.create_workout_day(%{
        day_label: "Lower",
        day_number: 1,
        estimated_duration_min: 60,
        is_rest_day: false,
        muscle_groups: ["quads", "glutes"],
        program_id: program.id,
        trainer_notes: "Own every squat.",
        week_number: 2,
        workout_type: "lower"
      })

    {:ok, second_week_exercise} =
      Programs.create_exercise(%{
        name: "Hack Squat",
        notes: "Drive evenly through the foot.",
        position: 1,
        reps: "8-10",
        rest_seconds: 120,
        sets: 4,
        weight_kg: 80.0,
        workout_day_id: second_week_workout_day.id
      })

    %{
      exercise: exercise,
      program: program,
      second_week_exercise: second_week_exercise,
      second_week_workout_day: second_week_workout_day,
      second_exercise: second_exercise,
      user: user,
      workout_day: workout_day
    }
  end

  defp trainer_user_with_profile do
    trainer = user_fixture(%{role: "trainer"})

    {:ok, _profile} =
      Profiles.upsert_trainer_profile(trainer.id, %{
        bio: "High-accountability coaching",
        certification: "NASM",
        max_clients: 20,
        specialization: "strength",
        years_experience: 5
      })

    trainer
  end
end
