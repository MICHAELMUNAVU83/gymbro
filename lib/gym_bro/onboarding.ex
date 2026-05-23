defmodule GymBro.Onboarding do
  @moduledoc """
  Shared onboarding flow decisions for athletes and trainers.
  """

  alias GymBro.Accounts.User
  alias GymBro.Profiles
  alias GymBro.Profiles.UserProfile

  @body_stats_path "/onboarding/body-stats"
  @goals_path "/onboarding/goals"
  @generating_path "/onboarding/generating"
  @trainer_setup_path "/onboarding/trainer-setup"
  @trainer_dashboard_path "/trainer"
  @athlete_home_path "/"

  def next_path(%User{role: "trainer"} = user) do
    if onboarding_complete?(user) do
      @trainer_dashboard_path
    else
      @trainer_setup_path
    end
  end

  def next_path(%User{} = user) do
    profile = Profiles.get_user_profile_by_user(user.id)

    cond do
      onboarding_complete?(user) -> @athlete_home_path
      not body_stats_complete?(profile) -> @body_stats_path
      not goals_complete?(profile) -> @goals_path
      true -> @generating_path
    end
  end

  def welcome_path(%User{role: "trainer"}), do: @trainer_setup_path
  def welcome_path(%User{}), do: @body_stats_path

  def onboarding_complete?(%User{role: "trainer"} = user) do
    not is_nil(Profiles.get_trainer_profile_by_user(user.id))
  end

  def onboarding_complete?(%User{} = user) do
    case Profiles.get_user_profile_by_user(user.id) do
      %UserProfile{onboarding_complete: true} -> true
      _ -> false
    end
  end

  def body_stats_complete?(%UserProfile{} = profile) do
    present_number?(profile.age) and present_number?(profile.height_cm) and present_number?(profile.weight_kg)
  end

  def body_stats_complete?(_), do: false

  def goals_complete?(%UserProfile{} = profile) do
    present_string?(profile.goal) and present_string?(profile.fitness_level) and
      present_string?(profile.equipment) and present_number?(profile.goal_weight_kg) and
      profile.days_per_week in [3, 4, 5]
  end

  def goals_complete?(_), do: false

  defp present_number?(value), do: is_integer(value) or is_float(value)

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
end
