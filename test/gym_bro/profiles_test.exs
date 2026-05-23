defmodule GymBro.ProfilesTest do
  use GymBro.DataCase

  alias GymBro.Profiles

  import GymBro.AccountsFixtures
  import GymBro.ProfilesFixtures

  describe "user profiles" do
    test "creates and fetches a user profile by user id" do
      user_profile = user_profile_fixture()

      assert Profiles.get_user_profile_by_user(user_profile.user_id).id == user_profile.id
      assert [fetched] = Profiles.list_user_profiles()
      assert fetched.id == user_profile.id
    end

    test "upserts a user profile for the same user" do
      user = user_fixture()

      assert {:ok, created} =
               Profiles.upsert_user_profile(user.id, %{
                 height_cm: 180.0,
                 weight_kg: 80.0,
                 goal_weight_kg: 76.0,
                 preferred_session_minutes: 45,
                 preferred_exercises_per_day: 3,
                 preferred_rest_days: [2, 4, 6, 7],
                 fitness_level: "beginner",
                 goal: "weight_loss",
                 days_per_week: 3,
                 equipment: "home"
               })

      assert {:ok, updated} =
               Profiles.upsert_user_profile(user.id, %{
                 days_per_week: 5,
                 equipment: "gym",
                 fitness_level: "advanced",
                 preferred_exercises_per_day: 5,
                 preferred_rest_days: [3, 7],
                 preferred_session_minutes: 75
               })

      assert created.id == updated.id
      assert updated.days_per_week == 5
      assert updated.equipment == "gym"
      assert updated.fitness_level == "advanced"
      assert updated.preferred_exercises_per_day == 5
      assert updated.preferred_rest_days == [3, 7]
      assert updated.preferred_session_minutes == 75
    end

    test "validates preferred rest day count against training days" do
      user = user_fixture()

      assert {:error, changeset} =
               Profiles.upsert_user_profile(user.id, %{
                 days_per_week: 4,
                 preferred_rest_days: [2],
                 preferred_exercises_per_day: 4,
                 equipment: "gym",
                 fitness_level: "intermediate",
                 goal: "maintenance",
                 preferred_session_minutes: 60
               })

      assert "must include exactly 3 rest days" in errors_on(changeset).preferred_rest_days
    end
  end

  describe "trainer profiles" do
    test "creates and fetches a trainer profile by user id" do
      trainer_profile = trainer_profile_fixture()

      assert Profiles.get_trainer_profile_by_user(trainer_profile.user_id).id ==
               trainer_profile.id

      assert [fetched] = Profiles.list_trainer_profiles()
      assert fetched.id == trainer_profile.id
    end

    test "enforces one trainer profile per user" do
      trainer_profile = trainer_profile_fixture()

      assert {:error, changeset} =
               Profiles.create_trainer_profile(%{
                 user_id: trainer_profile.user_id,
                 specialization: "strength"
               })

      assert "has already been taken" in errors_on(changeset).user_id
    end
  end
end
