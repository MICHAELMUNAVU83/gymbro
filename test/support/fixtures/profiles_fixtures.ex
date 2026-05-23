defmodule GymBro.ProfilesFixtures do
  @moduledoc """
  Test helpers for the `GymBro.Profiles` context.
  """

  import GymBro.AccountsFixtures

  def user_profile_fixture(attrs \\ %{}) do
    user = user_fixture()

    {:ok, user_profile} =
      attrs
      |> Enum.into(%{
        age: 28,
        days_per_week: 4,
        equipment: "gym",
        fitness_level: "intermediate",
        goal: "muscle_gain",
        goal_weight_kg: 82.0,
        height_cm: 178.0,
        onboarding_complete: true,
        preferred_block_weeks: 9,
        preferred_exercises_per_day: 4,
        preferred_rest_days: [3, 6, 7],
        preferred_session_minutes: 60,
        user_id: user.id,
        weight_kg: 79.5
      })
      |> GymBro.Profiles.create_user_profile()

    user_profile
  end

  def trainer_profile_fixture(attrs \\ %{}) do
    trainer = user_fixture(%{role: "trainer"})

    {:ok, trainer_profile} =
      attrs
      |> Enum.into(%{
        bio: "Strength coach focused on sustainable progress.",
        certification: "NASM-CPT",
        max_clients: 20,
        specialization: "strength",
        user_id: trainer.id,
        years_experience: 6
      })
      |> GymBro.Profiles.create_trainer_profile()

    trainer_profile
  end
end
