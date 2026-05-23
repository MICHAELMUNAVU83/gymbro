defmodule GymBroWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use GymBroWeb, :html

  embed_templates "page_html/*"

  def pretty_goal(nil), do: "No goal yet"
  def pretty_goal("weight_loss"), do: "Weight loss"
  def pretty_goal("muscle_gain"), do: "Muscle gain"
  def pretty_goal("maintenance"), do: "Maintenance"
  def pretty_goal(value), do: to_string(value)

  def format_weight(nil), do: "--"
  def format_weight(value) when is_integer(value), do: "#{value}.0 kg"

  def format_weight(value) when is_float(value),
    do: "#{:erlang.float_to_binary(value, decimals: 1)} kg"

  def format_number(nil), do: "--"
  def format_number(value) when is_integer(value), do: Integer.to_string(value)
  def format_number(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)

  def format_minutes(nil), do: "--"
  def format_minutes(value), do: "#{value} min"

  def chart_line_opacity(points) when length(points) > 1, do: "1"
  def chart_line_opacity(_points), do: "0"

  def consistency_caption(%{completed_count: completed_count, planned_days: planned_days}) do
    "#{completed_count}/#{planned_days} workouts finished this week"
  end

  def next_workout_heading(nil), do: "No program yet"

  def next_workout_heading(next_workout) do
    next_workout.day_label || pretty_workout_type(next_workout.workout_type)
  end

  def next_workout_focus(nil), do: "Generate your first program to unlock your next session."

  def next_workout_focus(next_workout) do
    case next_workout.muscle_groups do
      [] -> "Your next session is lined up and ready."
      groups -> Enum.map_join(groups, " • ", &titleize/1)
    end
  end

  def first_exercise_names(nil), do: []

  def first_exercise_names(next_workout) do
    next_workout.exercises
    |> Enum.take(3)
    |> Enum.map(& &1.name)
  end

  def macro_initial(label), do: String.first(label)

  def streak_caption(%{current_days: current_days, longest_days: longest_days}) do
    "Current #{current_days}-day streak · Best #{longest_days} day#{if longest_days == 1, do: "", else: "s"}"
  end

  defp pretty_workout_type(nil), do: "Workout"
  defp pretty_workout_type(value), do: titleize(value)

  defp titleize(value) do
    value
    |> to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
