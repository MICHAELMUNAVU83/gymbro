defmodule GymBro.Dashboard do
  @moduledoc """
  Read-model helpers for the athlete home dashboard.
  """

  alias GymBro.{Analytics, BodyStats, Programs, Training}

  @chart_width 320.0
  @chart_height 140.0
  @chart_padding 16.0

  def athlete_home(user, profile, today \\ Date.utc_today()) do
    summary = Analytics.athlete_summary(user.id)
    current_weight = summary.latest_weight_kg || profile_weight(profile)
    week_dates = week_dates(today)

    completed_sessions =
      Training.list_completed_workout_sessions_for_user_between(
        user.id,
        hd(week_dates),
        List.last(week_dates)
      )

    completed_dates = Training.list_completed_workout_dates_for_user(user.id)

    %{
      summary: summary,
      next_workout: Programs.get_next_workout_for_user(user.id),
      macro_targets: macro_targets(profile, current_weight),
      bodyweight_chart: bodyweight_chart(user.id, profile),
      workout_calendar: workout_calendar(completed_dates, today),
      workout_streak: workout_streak(completed_dates, today),
      consistency: consistency_snapshot(profile, completed_sessions),
      current_weight: current_weight
    }
  end

  defp profile_weight(nil), do: nil
  defp profile_weight(profile), do: profile.weight_kg

  defp macro_targets(profile, nil) do
    %{
      calories: 0,
      protein_g: 0,
      carbs_g: 0,
      fat_g: 0,
      goal_label: pretty_goal(profile && profile.goal)
    }
  end

  defp macro_targets(profile, current_weight) do
    goal = profile && profile.goal

    {calorie_factor, protein_factor, fat_factor} =
      case goal do
        "weight_loss" -> {28, 2.2, 0.8}
        "muscle_gain" -> {34, 2.0, 0.9}
        _ -> {31, 1.8, 0.85}
      end

    calories = round(current_weight * calorie_factor)
    protein_g = round(current_weight * protein_factor)
    fat_g = round(current_weight * fat_factor)
    carbs_g = max(round((calories - protein_g * 4 - fat_g * 9) / 4), 0)

    %{
      calories: calories,
      protein_g: protein_g,
      carbs_g: carbs_g,
      fat_g: fat_g,
      goal_label: pretty_goal(goal)
    }
  end

  defp bodyweight_chart(user_id, profile) do
    logs = BodyStats.list_recent_body_weight_logs_for_user(user_id, 8)

    points =
      case logs do
        [] ->
          fallback_bodyweight_point(profile)

        list ->
          Enum.map(list, fn log ->
            %{label: Calendar.strftime(log.logged_at, "%b %-d"), weight_kg: log.weight_kg}
          end)
      end

    weights = Enum.map(points, & &1.weight_kg)

    case weights do
      [] ->
        %{points: [], polyline_points: "", min_weight: nil, max_weight: nil}

      _ ->
        min_weight = Enum.min(weights)
        max_weight = Enum.max(weights)
        lower_bound = min_weight - 5
        upper_bound = max_weight + 5
        x_step = x_step(points)

        chart_points =
          points
          |> Enum.with_index()
          |> Enum.map(fn {%{label: label, weight_kg: weight_kg}, index} ->
            x = @chart_padding + x_step * index
            y = scaled_weight_y(weight_kg, lower_bound, upper_bound)

            %{
              x: x,
              y: y,
              label: label,
              weight_kg: weight_kg
            }
          end)

        %{
          points: chart_points,
          polyline_points: Enum.map_join(chart_points, " ", &"#{&1.x},#{&1.y}"),
          min_weight: min_weight,
          max_weight: max_weight
        }
    end
  end

  defp fallback_bodyweight_point(nil), do: []

  defp fallback_bodyweight_point(profile) do
    if profile.weight_kg do
      [%{label: "Start", weight_kg: profile.weight_kg}]
    else
      []
    end
  end

  defp x_step(points) when length(points) <= 1 do
    0.0
  end

  defp x_step(points) do
    (@chart_width - @chart_padding * 2) / (length(points) - 1)
  end

  defp scaled_weight_y(weight, lower_bound, upper_bound) do
    usable_height = @chart_height - @chart_padding * 2
    ratio = (weight - lower_bound) / max(upper_bound - lower_bound, 1)
    @chart_height - @chart_padding - ratio * usable_height
  end

  defp consistency_snapshot(profile, completed_sessions) do
    planned_days = (profile && profile.days_per_week) || 0
    completed_count = length(completed_sessions)

    percent =
      if planned_days > 0, do: min(round(completed_count / planned_days * 100), 100), else: 0

    %{
      completed_count: completed_count,
      planned_days: planned_days,
      percent: percent
    }
  end

  defp week_dates(today) do
    beginning_of_week = Date.add(today, 1 - Date.day_of_week(today))
    Enum.map(0..6, &Date.add(beginning_of_week, &1))
  end

  defp workout_calendar(completed_dates, today) do
    completed_dates = MapSet.new(completed_dates)
    start_date = Date.add(today, -34)

    days =
      Enum.map(0..34, fn offset ->
        date = Date.add(start_date, offset)

        %{
          date: date,
          day_number: date.day,
          is_today: date == today,
          worked_out: MapSet.member?(completed_dates, date)
        }
      end)

    %{
      days: days,
      month_label: calendar_range_label(start_date, today),
      completed_days: Enum.count(days, & &1.worked_out)
    }
  end

  defp workout_streak(completed_dates, today) do
    completed_dates = MapSet.new(completed_dates)

    %{
      current_days: count_streak(completed_dates, today),
      longest_days: longest_streak(completed_dates)
    }
  end

  defp count_streak(completed_dates, today) do
    if MapSet.member?(completed_dates, today) do
      do_count_streak(completed_dates, today, 0)
    else
      0
    end
  end

  defp do_count_streak(completed_dates, date, acc) do
    if MapSet.member?(completed_dates, date) do
      do_count_streak(completed_dates, Date.add(date, -1), acc + 1)
    else
      acc
    end
  end

  defp longest_streak(completed_dates) do
    completed_dates
    |> MapSet.to_list()
    |> Enum.sort()
    |> Enum.reduce({0, 0, nil}, fn date, {longest, current, previous_date} ->
      next_current =
        case previous_date do
          nil ->
            1

          previous ->
            if Date.diff(date, previous) == 1, do: current + 1, else: 1
        end

      {max(longest, next_current), next_current, date}
    end)
    |> elem(0)
  end

  defp calendar_range_label(start_date, end_date) do
    start_label = Calendar.strftime(start_date, "%b %-d")
    end_label = Calendar.strftime(end_date, "%b %-d")
    "#{start_label} - #{end_label}"
  end

  defp pretty_goal("weight_loss"), do: "Weight loss"
  defp pretty_goal("muscle_gain"), do: "Muscle gain"
  defp pretty_goal("maintenance"), do: "Maintenance"
  defp pretty_goal(nil), do: "Balanced fuel"
  defp pretty_goal(goal), do: goal
end
