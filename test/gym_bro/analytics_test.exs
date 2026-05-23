defmodule GymBro.AnalyticsTest do
  use GymBro.DataCase

  alias GymBro.Analytics
  alias GymBro.Profiles

  import GymBro.AccountsFixtures
  import GymBro.BodyStatsFixtures
  import GymBro.TrainerFixtures
  import GymBro.TrainingFixtures

  test "builds an athlete summary" do
    user = user_fixture()

    body_weight_log_fixture(%{user_id: user.id, weight_kg: 81.2})
    checkin_image_fixture(%{user_id: user.id})
    personal_record_fixture(%{user_id: user.id})
    workout_session_fixture(%{user_id: user.id, status: "completed"})

    assert %{
             total_sessions: 1,
             completed_sessions: 1,
             personal_records: 1,
             checkins: 1,
             latest_weight_kg: 81.2
           } = Analytics.athlete_summary(user.id)
  end

  test "builds a trainer summary" do
    relationship = trainer_client_fixture()
    client_invitation_fixture(%{trainer_id: relationship.trainer_id, status: "pending"})
    workout_session_fixture(%{user_id: relationship.client_id, status: "completed"})

    assert %{
             total_clients: 1,
             active_clients: 1,
             pending_invitations: 1,
             total_client_sessions: 1,
             completed_client_sessions: 1
           } = Analytics.trainer_summary(relationship.trainer_id)
  end

  test "builds a trainer overview with average consistency and weight loss leaders" do
    today = ~D[2026-05-21]
    trainer = user_fixture(%{role: "trainer"})
    casey = user_fixture(%{email: "casey.client@example.com"})
    jamie = user_fixture(%{email: "jamie.client@example.com"})

    trainer_client_fixture(%{trainer_id: trainer.id, client_id: casey.id})
    trainer_client_fixture(%{trainer_id: trainer.id, client_id: jamie.id})

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

    workout_session_fixture(%{
      completed_at: ~U[2026-05-19 09:00:00Z],
      started_at: ~U[2026-05-19 08:10:00Z],
      status: "completed",
      user_id: casey.id
    })

    workout_session_fixture(%{
      completed_at: ~U[2026-05-21 09:00:00Z],
      started_at: ~U[2026-05-21 08:05:00Z],
      status: "completed",
      user_id: casey.id
    })

    workout_session_fixture(%{
      completed_at: ~U[2026-05-20 18:00:00Z],
      started_at: ~U[2026-05-20 17:20:00Z],
      status: "completed",
      user_id: jamie.id
    })

    body_weight_log_fixture(%{logged_at: ~D[2026-05-01], user_id: casey.id, weight_kg: 82.0})
    body_weight_log_fixture(%{logged_at: ~D[2026-05-21], user_id: casey.id, weight_kg: 79.5})
    body_weight_log_fixture(%{logged_at: ~D[2026-05-02], user_id: jamie.id, weight_kg: 88.0})
    body_weight_log_fixture(%{logged_at: ~D[2026-05-21], user_id: jamie.id, weight_kg: 86.8})

    overview = Analytics.trainer_overview(trainer.id, today)

    assert overview.summary.total_client_sessions == 3
    assert overview.summary.completed_client_sessions == 3
    assert overview.avg_consistency.percent == 42
    assert overview.avg_consistency.client_count == 2
    assert overview.aggregate.weekly_completed_sessions == 3
    assert overview.aggregate.total_weight_lost_kg == 3.7
    assert overview.aggregate.average_weight_lost_kg == 1.9
    assert overview.aggregate.clients_losing_weight_count == 2
    assert overview.aggregate.clients_with_weight_data_count == 2
    assert overview.week_range_label == "May 18 - May 24"

    assert [
             %{client_name: "Casey Client", weight_lost_kg: 2.5, consistency_percent: 50},
             %{client_name: "Jamie Client", weight_lost_kg: 1.2, consistency_percent: 33}
           ] = overview.weight_loss_leaders
  end
end
