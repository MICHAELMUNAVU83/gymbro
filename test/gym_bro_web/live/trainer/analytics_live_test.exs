defmodule GymBroWeb.Trainer.AnalyticsLiveTest do
  use GymBroWeb.ConnCase, async: false

  import GymBro.AccountsFixtures
  import GymBro.BodyStatsFixtures
  import Phoenix.LiveViewTest

  alias GymBro.Profiles

  test "renders trainer analytics with sessions, consistency, and weight-loss leaders", %{
    conn: conn
  } do
    trainer = user_fixture(%{role: "trainer"})
    casey = user_fixture(%{email: "casey.client@example.com"})
    jamie = user_fixture(%{email: "jamie.client@example.com"})

    {:ok, _trainer_profile} =
      Profiles.upsert_trainer_profile(trainer.id, %{
        bio: "Data-aware coaching",
        certification: "NASM",
        max_clients: 12,
        specialization: "fat_loss",
        years_experience: 6
      })

    {:ok, _casey_profile} =
      Profiles.upsert_user_profile(casey.id, %{
        age: 28,
        days_per_week: 4,
        equipment: "gym",
        fitness_level: "intermediate",
        goal: "weight_loss",
        goal_weight_kg: 74.0,
        height_cm: 176.0,
        onboarding_complete: true,
        weight_kg: 82.0
      })

    {:ok, _jamie_profile} =
      Profiles.upsert_user_profile(jamie.id, %{
        age: 31,
        days_per_week: 3,
        equipment: "gym",
        fitness_level: "beginner",
        goal: "weight_loss",
        goal_weight_kg: 76.0,
        height_cm: 170.0,
        onboarding_complete: true,
        weight_kg: 88.0
      })

    {:ok, _casey_relationship} =
      GymBro.Trainer.create_trainer_client(%{
        client_id: casey.id,
        joined_at: ~D[2026-05-09],
        status: "active",
        trainer_id: trainer.id
      })

    {:ok, _jamie_relationship} =
      GymBro.Trainer.create_trainer_client(%{
        client_id: jamie.id,
        joined_at: ~D[2026-05-10],
        status: "active",
        trainer_id: trainer.id
      })

    body_weight_log_fixture(%{logged_at: ~D[2026-05-01], user_id: casey.id, weight_kg: 82.0})
    body_weight_log_fixture(%{logged_at: ~D[2026-05-21], user_id: casey.id, weight_kg: 79.5})
    body_weight_log_fixture(%{logged_at: ~D[2026-05-02], user_id: jamie.id, weight_kg: 88.0})
    body_weight_log_fixture(%{logged_at: ~D[2026-05-21], user_id: jamie.id, weight_kg: 86.8})

    insert_completed_session(casey.id, ~U[2026-05-19 09:00:00Z], ~U[2026-05-19 08:10:00Z])
    insert_completed_session(casey.id, ~U[2026-05-21 09:00:00Z], ~U[2026-05-21 08:05:00Z])
    insert_completed_session(jamie.id, ~U[2026-05-20 18:00:00Z], ~U[2026-05-20 17:20:00Z])

    conn = log_in_user(conn, trainer)
    {:ok, _view, html} = live(conn, ~p"/trainer/analytics")

    assert html =~ "Trainer analytics"
    assert html =~ "Sessions"
    assert html =~ "42%"
    assert html =~ "3.7 kg lost"
    assert html =~ "Casey Client"
    assert html =~ "Jamie Client"
    assert html =~ "May 18 - May 24"
    assert html =~ "Who is building momentum"
    assert html =~ "Weekly snapshot"
  end

  defp insert_completed_session(user_id, completed_at, started_at) do
    workout_day = GymBro.ProgramsFixtures.workout_day_fixture()

    {:ok, _session} =
      GymBro.Training.create_workout_session(%{
        completed_at: completed_at,
        duration_seconds: DateTime.diff(completed_at, started_at, :second),
        started_at: started_at,
        status: "completed",
        user_id: user_id,
        workout_day_id: workout_day.id
      })
  end
end
