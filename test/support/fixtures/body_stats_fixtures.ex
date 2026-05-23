defmodule GymBro.BodyStatsFixtures do
  @moduledoc """
  Test helpers for the `GymBro.BodyStats` context.
  """

  import GymBro.AccountsFixtures

  def body_weight_log_fixture(attrs \\ %{}) do
    user = user_fixture()

    {:ok, body_weight_log} =
      attrs
      |> Enum.into(%{
        logged_at: ~D[2026-05-09],
        notes: "Morning weigh-in.",
        user_id: user.id,
        weight_kg: 79.4
      })
      |> GymBro.BodyStats.create_body_weight_log()

    body_weight_log
  end

  def checkin_image_fixture(attrs \\ %{}) do
    user = user_fixture()

    {:ok, checkin_image} =
      attrs
      |> Enum.into(%{
        image_type: "front",
        image_url: "https://example.com/checkins/front.jpg",
        logged_at: ~D[2026-05-09],
        notes: "Week 1 progress photo.",
        user_id: user.id,
        visible_to_trainer: true
      })
      |> GymBro.BodyStats.create_checkin_image()

    checkin_image
  end

  def personal_record_fixture(attrs \\ %{}) do
    user = user_fixture()

    {:ok, personal_record} =
      attrs
      |> Enum.into(%{
        achieved_at: ~D[2026-05-09],
        exercise_name: "Bench Press",
        reps: 5,
        user_id: user.id,
        weight_kg: 100.0
      })
      |> GymBro.BodyStats.create_personal_record()

    personal_record
  end
end
