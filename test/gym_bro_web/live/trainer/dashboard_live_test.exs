defmodule GymBroWeb.Trainer.DashboardLiveTest do
  use GymBroWeb.ConnCase, async: false

  import GymBro.AccountsFixtures
  import GymBro.BodyStatsFixtures
  import Phoenix.LiveViewTest

  alias GymBro.{Profiles, Programs, Training}

  test "renders the trainer dashboard with roster, activity feed, alerts, and live status", %{
    conn: conn
  } do
    today = Date.utc_today()
    trainer = user_fixture(%{role: "trainer"})
    client = user_fixture(%{email: "casey.client@example.com"})
    stale_client = user_fixture(%{email: "jamie.stale@example.com"})

    {:ok, _profile} =
      Profiles.upsert_trainer_profile(trainer.id, %{
        bio: "High-accountability coaching",
        certification: "NASM",
        max_clients: 20,
        specialization: "strength",
        years_experience: 5
      })

    {:ok, _client_profile} =
      Profiles.upsert_user_profile(client.id, %{
        age: 28,
        days_per_week: 4,
        equipment: "gym",
        fitness_level: "intermediate",
        goal: "muscle_gain",
        goal_weight_kg: 84.0,
        height_cm: 176.0,
        onboarding_complete: true,
        weight_kg: 80.0
      })

    {:ok, _stale_profile} =
      Profiles.upsert_user_profile(stale_client.id, %{
        age: 31,
        days_per_week: 5,
        equipment: "gym",
        fitness_level: "advanced",
        goal: "weight_loss",
        goal_weight_kg: 74.0,
        height_cm: 172.0,
        onboarding_complete: true,
        weight_kg: 79.0
      })

    {:ok, _relationship_one} =
      GymBro.Trainer.create_trainer_client(%{
        client_id: client.id,
        joined_at: today,
        status: "active",
        trainer_id: trainer.id
      })

    {:ok, _relationship_two} =
      GymBro.Trainer.create_trainer_client(%{
        client_id: stale_client.id,
        joined_at: Date.add(today, -14),
        status: "active",
        trainer_id: trainer.id
      })

    {:ok, client_program} =
      Programs.create_program(%{
        ai_raw_plan: %{},
        created_by_id: trainer.id,
        current_phase: 1,
        current_week: 1,
        description: "Coached build block",
        name: "Client build",
        phase_name: "Foundation",
        source: "trainer",
        status: "active",
        total_weeks: 12,
        user_id: client.id
      })

    {:ok, client_workout_day} =
      Programs.create_workout_day(%{
        day_label: "Upper",
        day_number: 1,
        estimated_duration_min: 60,
        is_rest_day: false,
        muscle_groups: ["chest", "back"],
        program_id: client_program.id,
        week_number: 1,
        workout_type: "upper"
      })

    {:ok, stale_program} =
      Programs.create_program(%{
        ai_raw_plan: %{},
        created_by_id: trainer.id,
        current_phase: 1,
        current_week: 1,
        description: "Fat-loss block",
        name: "Client cut",
        phase_name: "Foundation",
        source: "trainer",
        status: "active",
        total_weeks: 12,
        user_id: stale_client.id
      })

    {:ok, stale_workout_day} =
      Programs.create_workout_day(%{
        day_label: "Legs",
        day_number: 1,
        estimated_duration_min: 55,
        is_rest_day: false,
        muscle_groups: ["legs"],
        program_id: stale_program.id,
        week_number: 1,
        workout_type: "legs"
      })

    {:ok, _live_session} =
      Training.create_workout_session(%{
        started_at: DateTime.utc_now() |> DateTime.truncate(:second),
        status: "active",
        user_id: client.id,
        workout_day_id: client_workout_day.id
      })

    {:ok, _completed_session} =
      Training.create_workout_session(%{
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        duration_seconds: 2_700,
        started_at:
          DateTime.add(DateTime.utc_now(), -3_000, :second) |> DateTime.truncate(:second),
        status: "completed",
        user_id: client.id,
        workout_day_id: client_workout_day.id
      })

    {:ok, _stale_completed_session} =
      Training.create_workout_session(%{
        completed_at:
          DateTime.new!(Date.add(today, -6), ~T[08:30:00], "Etc/UTC")
          |> DateTime.truncate(:second),
        duration_seconds: 2_400,
        started_at:
          DateTime.new!(Date.add(today, -6), ~T[07:50:00], "Etc/UTC")
          |> DateTime.truncate(:second),
        status: "completed",
        user_id: stale_client.id,
        workout_day_id: stale_workout_day.id
      })

    body_weight_log_fixture(%{
      logged_at: today,
      user_id: client.id,
      weight_kg: 79.4
    })

    checkin_image_fixture(%{
      image_type: "front",
      logged_at: today,
      user_id: client.id
    })

    checkin_image_fixture(%{
      image_type: "side",
      logged_at: Date.add(today, -12),
      user_id: stale_client.id
    })

    conn = log_in_user(conn, trainer)
    {:ok, view, html} = live(conn, ~p"/trainer")

    assert html =~ "Keep eyes on every athlete"
    assert html =~ "Casey Client"
    assert html =~ "started a live session"
    assert html =~ "checked in on bodyweight"
    assert html =~ "shared a progress photo"
    assert html =~ "Jamie Stale"
    assert html =~ "Missed sessions"
    assert html =~ "No check-in"

    send(view.pid, {:client_session_event, :set_logged, %{}})
    assert render(view) =~ "Follow-up queue"
  end
end
