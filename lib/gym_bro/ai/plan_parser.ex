defmodule GymBro.AI.PlanParser do
  @moduledoc """
  Parses AI-generated workout plans into normalized attrs for programs,
  workout days, and exercises.
  """

  @default_program_status "draft"
  @default_program_source "ai"

  @type parsed_plan :: %{
          program: map(),
          workout_days: [map()],
          raw_plan: map()
        }

  @spec parse(binary() | map()) :: {:ok, parsed_plan()} | {:error, term()}
  def parse(plan) when is_binary(plan) do
    plan
    |> strip_code_fences()
    |> Jason.decode()
    |> case do
      {:ok, decoded_plan} -> parse(decoded_plan)
      {:error, reason} -> {:error, {:invalid_json, reason}}
    end
  end

  def parse(%{} = plan) do
    with {:ok, phases} <- fetch_list(plan, "phases"),
         {:ok, workout_days} <- build_workout_days(phases) do
      program_attrs = build_program_attrs(plan, phases, workout_days)

      {:ok,
       %{
         program: program_attrs,
         workout_days: workout_days,
         raw_plan: plan
       }}
    end
  end

  def parse(_), do: {:error, :invalid_plan}

  defp build_program_attrs(plan, phases, workout_days) do
    first_phase = List.first(phases) || %{}
    total_weeks = infer_total_weeks(phases, workout_days)

    %{
      name: get_string(plan, "program_name"),
      description: get_string(plan, "description"),
      total_weeks: total_weeks,
      current_week: 1,
      current_phase: get_integer(first_phase, "phase", 1),
      phase_name: get_string(first_phase, "name"),
      status: @default_program_status,
      source: @default_program_source
    }
  end

  defp build_workout_days(phases) do
    phases
    |> Enum.reduce_while({:ok, []}, fn phase, {:ok, acc_days} ->
      case build_phase_days(phase) do
        {:ok, days} -> {:cont, {:ok, acc_days ++ days}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, []} -> {:error, :no_workout_days}
      {:ok, workout_days} -> {:ok, Enum.sort_by(workout_days, &{&1.week_number, &1.day_number})}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_phase_days(phase) do
    with {:ok, weeks_data} <- fetch_list(phase, "weeks_data") do
      phase
      |> expand_phase_weeks(weeks_data)
      |> Enum.reduce_while({:ok, []}, fn week_data, {:ok, acc_days} ->
        case build_week_days(week_data) do
          {:ok, days} -> {:cont, {:ok, acc_days ++ days}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp expand_phase_weeks(phase, weeks_data) do
    phase_weeks =
      phase
      |> get_list("weeks", [])
      |> Enum.map(&normalize_integer/1)
      |> Enum.filter(&is_integer/1)

    case {phase_weeks, weeks_data} do
      {[], _templates} ->
        weeks_data

      {_phase_weeks, []} ->
        []

      {phase_weeks, templates} ->
        last_template_index = max(length(templates) - 1, 0)

        Enum.with_index(phase_weeks)
        |> Enum.map(fn {week_number, index} ->
          template =
            Enum.find(templates, &(get_integer(&1, "week") == week_number)) ||
              Enum.at(templates, min(index, last_template_index)) ||
              List.first(templates)

          Map.put(template, "week", week_number)
        end)
    end
  end

  defp build_week_days(week_data) do
    week_number = get_integer(week_data, "week")

    with true <- is_integer(week_number) and week_number > 0,
         {:ok, days} <- fetch_list(week_data, "days") do
      days
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, []}, fn {day, fallback_day_number}, {:ok, acc_days} ->
        case build_day(day, week_number, fallback_day_number) do
          {:ok, parsed_day} -> {:cont, {:ok, [parsed_day | acc_days]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, parsed_days} -> {:ok, Enum.reverse(parsed_days)}
        {:error, reason} -> {:error, reason}
      end
    else
      false -> {:error, {:invalid_week, week_data}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_day(day, week_number, fallback_day_number) do
    day_number = get_integer(day, "day", fallback_day_number)

    with true <- is_integer(day_number) and day_number > 0,
         {:ok, exercises} <- build_exercises(get_list(day, "exercises", [])) do
      is_rest_day = get_boolean(day, "is_rest_day", false)
      workout_type = infer_workout_type(day, is_rest_day)
      day_label = infer_day_label(day, is_rest_day)

      {:ok,
       %{
         week_number: week_number,
         day_number: day_number,
         day_label: day_label,
         workout_type: workout_type,
         estimated_duration_min: get_integer(day, "estimated_duration_min"),
         muscle_groups: get_string_list(day, "muscle_groups"),
         is_rest_day: is_rest_day,
         exercises: exercises
       }}
    else
      false -> {:error, {:invalid_day, %{week_number: week_number, day: day}}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_exercises(exercises) do
    exercises
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {exercise, fallback_position}, {:ok, acc_exercises} ->
      case build_exercise(exercise, fallback_position) do
        {:ok, parsed_exercise} -> {:cont, {:ok, [parsed_exercise | acc_exercises]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, parsed_exercises} ->
        sorted_exercises =
          parsed_exercises
          |> Enum.sort_by(& &1.position)

        {:ok, sorted_exercises}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_exercise(exercise, fallback_position) do
    name = get_string(exercise, "name")
    position = get_integer(exercise, "position", fallback_position)

    cond do
      is_nil(name) or name == "" ->
        {:error, {:invalid_exercise, exercise}}

      not (is_integer(position) and position > 0) ->
        {:error, {:invalid_exercise, exercise}}

      true ->
        {:ok,
         %{
           position: position,
           name: name,
           sets: get_integer(exercise, "sets"),
           reps: get_string(exercise, "reps"),
           rest_seconds: get_integer(exercise, "rest_seconds"),
           weight_kg: get_float(exercise, "weight_kg"),
           notes: get_string(exercise, "notes"),
           trainer_notes: get_string(exercise, "trainer_notes"),
           visual_guide: get_string(exercise, "visual_guide"),
           is_timed: get_boolean(exercise, "is_timed", false),
           duration_seconds: get_integer(exercise, "duration_seconds")
         }}
    end
  end

  defp infer_total_weeks(phases, workout_days) do
    phase_weeks =
      phases
      |> Enum.flat_map(&get_list(&1, "weeks", []))
      |> Enum.map(&normalize_integer/1)
      |> Enum.filter(&is_integer/1)

    workout_weeks =
      workout_days
      |> Enum.map(& &1.week_number)
      |> Enum.filter(&is_integer/1)

    case Enum.uniq(phase_weeks ++ workout_weeks) do
      [] -> 1
      unique_weeks -> length(unique_weeks)
    end
  end

  defp infer_workout_type(day, true) do
    get_string(day, "type") || "rest"
  end

  defp infer_workout_type(day, false) do
    get_string(day, "type")
  end

  defp infer_day_label(day, true) do
    get_string(day, "label") || "Rest"
  end

  defp infer_day_label(day, false) do
    get_string(day, "label")
  end

  defp fetch_list(map, key) do
    case get_list(map, key, nil) do
      list when is_list(list) -> {:ok, list}
      _ -> {:error, {:missing_list, key}}
    end
  end

  defp get_list(map, key, default) do
    case get_value(map, key) do
      list when is_list(list) -> list
      nil -> default
      _ -> default
    end
  end

  defp get_string_list(map, key) do
    map
    |> get_list(key, [])
    |> Enum.map(&to_string/1)
  end

  defp get_string(map, key) do
    case get_value(map, key) do
      nil -> nil
      value when is_binary(value) -> String.trim(value)
      value -> to_string(value)
    end
  end

  defp get_integer(map, key, default \\ nil) do
    map
    |> get_value(key)
    |> normalize_integer(default)
  end

  defp get_float(map, key) do
    map
    |> get_value(key)
    |> normalize_float()
  end

  defp get_boolean(map, key, default) do
    case get_value(map, key) do
      value when is_boolean(value) -> value
      "true" -> true
      "false" -> false
      nil -> default
      _ -> default
    end
  end

  defp get_value(map, key) when is_map(map) and is_binary(key) do
    cond do
      Map.has_key?(map, key) ->
        Map.get(map, key)

      true ->
        case safe_to_existing_atom(key) do
          {:ok, atom_key} -> Map.get(map, atom_key)
          :error -> nil
        end
    end
  end

  defp get_value(map, key) when is_map(map), do: Map.get(map, key)

  defp normalize_integer(nil, default), do: default
  defp normalize_integer(value, _default) when is_integer(value), do: value

  defp normalize_integer(value, _default) when is_float(value) do
    trunc(value)
  end

  defp normalize_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> default
    end
  end

  defp normalize_integer(_, default), do: default

  defp normalize_integer(value), do: normalize_integer(value, nil)

  defp normalize_float(nil), do: nil
  defp normalize_float(value) when is_float(value), do: value
  defp normalize_float(value) when is_integer(value), do: value / 1

  defp normalize_float(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp normalize_float(_), do: nil

  defp strip_code_fences(plan) do
    plan
    |> String.trim()
    |> String.replace(~r/\A```(?:json)?\s*/u, "")
    |> String.replace(~r/\s*```\z/u, "")
    |> String.trim()
  end

  defp safe_to_existing_atom(key) do
    {:ok, String.to_existing_atom(key)}
  rescue
    ArgumentError -> :error
  end
end
