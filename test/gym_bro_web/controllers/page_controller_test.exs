defmodule GymBroWeb.PageControllerTest do
  use GymBroWeb.ConnCase

  alias GymBro.{BodyStats, Profiles, Programs, Training}
  import GymBro.AccountsFixtures

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Free AI Workout Plans Built Around Your Goal"
  end

  test "GET / redirects incomplete athletes into onboarding", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/onboarding/body-stats"
  end

  test "GET / renders the athlete dashboard after onboarding", %{conn: conn} do
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
        weight_kg: 79.5
      })

    {:ok, program} =
      Programs.create_program(%{
        ai_raw_plan: %{"weeks" => 12},
        created_by_id: user.id,
        current_phase: 1,
        current_week: 1,
        description: "Hypertrophy block",
        name: "Build Phase",
        phase_name: "Foundation",
        source: "ai",
        status: "active",
        total_weeks: 12,
        user_id: user.id
      })

    {:ok, completed_day} =
      Programs.create_workout_day(%{
        day_label: "Push",
        day_number: 1,
        estimated_duration_min: 55,
        is_rest_day: false,
        muscle_groups: ["chest", "shoulders", "triceps"],
        program_id: program.id,
        trainer_notes: "Drive each set with intent.",
        week_number: 1,
        workout_type: "push"
      })

    {:ok, next_day} =
      Programs.create_workout_day(%{
        day_label: "Pull",
        day_number: 2,
        estimated_duration_min: 60,
        is_rest_day: false,
        muscle_groups: ["back", "biceps"],
        program_id: program.id,
        trainer_notes: "Pause at the top of every row.",
        week_number: 1,
        workout_type: "pull"
      })

    {:ok, _exercise} =
      Programs.create_exercise(%{
        name: "Chest-Supported Row",
        position: 1,
        reps: "10-12",
        rest_seconds: 90,
        sets: 4,
        workout_day_id: next_day.id
      })

    {:ok, _body_weight_log} =
      BodyStats.create_body_weight_log(%{
        logged_at: ~D[2026-05-09],
        user_id: user.id,
        weight_kg: 80.3
      })

    {:ok, _workout_session} =
      Training.create_workout_session(%{
        completed_at: ~U[2026-05-07 10:30:00Z],
        duration_seconds: 2_700,
        started_at: ~U[2026-05-07 09:45:00Z],
        status: "completed",
        user_id: user.id,
        workout_day_id: completed_day.id
      })

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/home"
  end

  test "GET / redirects onboarded trainers to the trainer dashboard", %{conn: conn} do
    trainer = user_fixture(%{role: "trainer"})

    {:ok, _profile} =
      Profiles.upsert_trainer_profile(trainer.id, %{
        bio: "Strength coach",
        certification: "NASM-CPT",
        max_clients: 20,
        specialization: "strength",
        years_experience: 5
      })

    conn =
      conn
      |> log_in_user(trainer)
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/trainer"
  end
end
