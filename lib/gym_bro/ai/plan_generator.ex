defmodule GymBro.AI.PlanGenerator do
  @moduledoc """
  Generates structured AI workout plans by calling the configured OpenAI client
  and normalizing the JSON response through `GymBro.AI.PlanParser`.
  """

  require Logger

  alias GymBro.AI.PlanParser
  alias GymBro.OpenAI

  @max_tokens 3_200

  @context """
  You are an expert personal trainer.
  Return compact valid JSON only.
  Return minified single-line JSON with no markdown.
  Keep all text short and practical.
  """

  @spec generate(map(), binary() | nil, map() | keyword()) ::
          {:ok, PlanParser.parsed_plan()} | {:error, term()}
  def generate(profile, trainer_notes \\ nil, opts \\ %{}) do
    block_weeks = preferred_block_weeks(profile, opts)
    prompt = build_prompt(profile, trainer_notes, opts)

    Logger.info(
      "AI plan generation requested goal=#{profile.goal} days_per_week=#{profile.days_per_week} requested_block_weeks=#{block_weeks}"
    )

    openai_client().send_request_to_openai(@context, prompt, max_tokens: @max_tokens)
    |> parse_response(block_weeks)
  end

  defp parse_response({:ok, json_string}, expected_block_weeks) do
    case PlanParser.parse(json_string) do
      {:ok, parsed_plan} ->
        parsed_plan
        |> normalize_block_weeks(expected_block_weeks)
        |> case do
          {:ok, normalized_plan} ->
            log_parsed_plan_summary(normalized_plan)
            {:ok, normalized_plan}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        log_parse_failure(reason, json_string)
        {:error, reason}
    end
  end

  defp parse_response({:error, reason}, _expected_block_weeks), do: {:error, reason}

  defp openai_client do
    Application.get_env(:gym_bro, :openai_client, OpenAI)
  end

  defp build_prompt(profile, trainer_notes, opts) do
    block_weeks = preferred_block_weeks(profile, opts)
    phase_specs = phase_specs(block_weeks)

    """
    Build a compact #{block_weeks}-week #{profile.goal} training plan.

    Athlete:
    - age: #{profile.age}
    - height_cm: #{profile.height_cm}
    - weight_kg: #{profile.weight_kg}
    - goal_weight_kg: #{profile.goal_weight_kg}
    - fitness_level: #{profile.fitness_level}
    - days_per_week: #{profile.days_per_week}
    - preferred_rest_days: #{preferred_rest_days(profile)}
    - preferred_exercises_per_day: #{preferred_exercises_per_day(profile)}
    - preferred_session_minutes: #{preferred_session_minutes(profile)}
    - preferred_block_weeks: #{block_weeks}
    - equipment: #{profile.equipment}#{trainer_notes_line(trainer_notes)}

    Rules:
    - use #{length(phase_specs)} phases across #{block_weeks} weeks
    #{phase_instructions(phase_specs)}
    - each template week must have exactly 7 day entries in order from day 1 to day 7
    - exactly #{profile.days_per_week} training days per week
    - make day #{preferred_rest_days_list(profile)} the rest day pattern when rest days are provided
    - use exactly #{preferred_exercises_per_day(profile)} exercises on each training day
    - prefer real gym-style exercises when equipment is gym or home gym: barbell, dumbbell, machine, cable, smith machine, leg press, hack squat, lat pulldown, seated row, RDL, split squat
    - avoid generic bodyweight-only choices like push-ups, plank, jumping jacks, or basic lunges unless equipment is minimal, it is a warm-up, or it clearly fits the goal
    - if conditioning is needed, prefer gym-friendly options like incline treadmill, rower, bike, sled, assault bike, ski erg, or loaded carries
    - keep estimated_duration_min close to #{preferred_session_minutes(profile)}
    - keep program_name, description, and phase names very short
    - omit notes unless essential
    - omit weight_kg unless essential
    - visual_guide should be a very short 5-10 word movement picture when useful
    - omit optional keys you do not need
    - use the same day split inside each phase
    - return exactly one weeks_data item per phase; we will reuse it for every week listed in that phase's weeks array
    - do not output all #{block_weeks} weeks in full
    - prefer short labels like Upper, Lower, Full, Cardio, Rest
    - return minified JSON on a single line

    Return JSON with this shape:
    {"program_name":"short name","description":"short description","phases":[{"phase":1,"name":"short phase name","weeks":[1,2,3],"weeks_data":[{"week":1,"days":[{"day":1,"label":"Upper","type":"upper","estimated_duration_min":60,"is_rest_day":false,"exercises":[{"position":1,"name":"Bench Press","sets":4,"reps":"8-10","rest_seconds":90,"visual_guide":"Chest tall, drive bar up"}]},{"day":2,"label":"Rest","type":"rest","is_rest_day":true,"exercises":[]}]}]}]}
    """
  end

  defp preferred_block_weeks(profile, opts) do
    opts = Map.new(opts)

    case Map.get(opts, :block_weeks) || Map.get(profile, :preferred_block_weeks) do
      weeks when is_integer(weeks) and weeks > 0 -> weeks
      _ -> 9
    end
  end

  defp phase_specs(block_weeks) when block_weeks > 0 do
    phase_count =
      cond do
        block_weeks <= 4 -> 1
        block_weeks <= 8 -> 2
        block_weeks <= 12 -> 3
        true -> 4
      end

    base_size = div(block_weeks, phase_count)
    remainder = rem(block_weeks, phase_count)

    {specs, _next_week} =
      Enum.reduce(1..phase_count, {[], 1}, fn phase_number, {acc, next_week} ->
        phase_size = base_size + if phase_number <= remainder, do: 1, else: 0
        weeks = Enum.to_list(next_week..(next_week + phase_size - 1))

        {
          acc ++ [%{phase: phase_number, weeks: weeks}],
          next_week + phase_size
        }
      end)

    specs
  end

  defp phase_instructions(phase_specs) do
    phase_specs
    |> Enum.map_join("\n", fn %{phase: phase_number, weeks: weeks} ->
      "- phase #{phase_number} must cover weeks #{Enum.join(weeks, ", ")}"
    end)
  end

  defp normalize_block_weeks(
         %{program: %{total_weeks: total_weeks}} = parsed_plan,
         expected_block_weeks
       )
       when total_weeks == expected_block_weeks do
    {:ok, parsed_plan}
  end

  defp normalize_block_weeks(
         %{program: %{total_weeks: returned_weeks}, raw_plan: raw_plan},
         expected_block_weeks
       ) do
    Logger.warning(
      "AI plan block length mismatch requested_block_weeks=#{expected_block_weeks} returned_block_weeks=#{returned_weeks} returned_phase_weeks=#{inspect(raw_plan_week_numbers(raw_plan))}; normalizing to requested length"
    )

    raw_plan
    |> normalize_raw_plan_block_weeks(expected_block_weeks)
    |> PlanParser.parse()
  end

  defp normalize_raw_plan_block_weeks(%{"phases" => phases} = raw_plan, expected_block_weeks)
       when is_list(phases) do
    desired_phase_specs = phase_specs(expected_block_weeks)
    fallback_week_template = fallback_week_template(phases)

    normalized_phases =
      desired_phase_specs
      |> Enum.with_index()
      |> Enum.map(fn {%{phase: phase_number, weeks: weeks}, index} ->
        phase_template =
          Enum.at(phases, min(index, max(length(phases) - 1, 0))) || %{}

        week_template =
          fallback_week_data(phase_template, fallback_week_template)
          |> Map.put("week", List.first(weeks))

        %{
          "phase" => phase_number,
          "name" => phase_name_for(phase_template, phase_number),
          "weeks" => weeks,
          "weeks_data" => [week_template]
        }
      end)

    raw_plan
    |> Map.put("phases", normalized_phases)
    |> Map.put(
      "description",
      normalize_description_block_weeks(raw_plan["description"], expected_block_weeks)
    )
  end

  defp normalize_raw_plan_block_weeks(raw_plan, _expected_block_weeks), do: raw_plan

  defp fallback_week_template(phases) do
    Enum.find_value(phases, %{}, fn phase ->
      phase
      |> Map.get("weeks_data", [])
      |> List.first()
    end)
  end

  defp fallback_week_data(phase_template, fallback_week_template) do
    phase_template
    |> Map.get("weeks_data", [])
    |> List.first()
    |> case do
      nil -> fallback_week_template
      template -> template
    end
  end

  defp phase_name_for(%{"name" => name}, _phase_number) when is_binary(name) and name != "",
    do: name

  defp phase_name_for(_phase_template, phase_number), do: "Phase #{phase_number}"

  defp normalize_description_block_weeks(description, expected_block_weeks)
       when is_binary(description) do
    Regex.replace(
      ~r/\b\d+\s*-\s*week\b|\b\d+\s+week\b/i,
      description,
      "#{expected_block_weeks}-week"
    )
  end

  defp normalize_description_block_weeks(_description, _expected_block_weeks), do: nil

  defp raw_plan_week_numbers(%{"phases" => phases}) when is_list(phases) do
    phases
    |> Enum.flat_map(fn phase -> Map.get(phase, "weeks", []) end)
    |> Enum.map(fn
      week when is_integer(week) ->
        week

      week when is_binary(week) ->
        case Integer.parse(week) do
          {parsed, _} -> parsed
          :error -> week
        end

      week ->
        week
    end)
  end

  defp raw_plan_week_numbers(_raw_plan), do: []

  defp preferred_session_minutes(%{preferred_session_minutes: minutes}) when is_integer(minutes),
    do: minutes

  defp preferred_session_minutes(_profile), do: 60

  defp preferred_exercises_per_day(%{preferred_exercises_per_day: count}) when is_integer(count),
    do: count

  defp preferred_exercises_per_day(_profile), do: 4

  defp preferred_rest_days(%{preferred_rest_days: rest_days}) when is_list(rest_days) do
    case Enum.sort(rest_days) do
      [] -> "AI can choose"
      sorted_days -> Enum.map_join(sorted_days, ", ", &rest_day_name/1)
    end
  end

  defp preferred_rest_days(_profile), do: "AI can choose"

  defp preferred_rest_days_list(%{preferred_rest_days: rest_days}) when is_list(rest_days) do
    case Enum.sort(rest_days) do
      [] -> "or AI-selected days"
      sorted_days -> Enum.map_join(sorted_days, ", ", &Integer.to_string/1)
    end
  end

  defp preferred_rest_days_list(_profile), do: "or AI-selected days"

  defp trainer_notes_line(nil), do: ""

  defp trainer_notes_line(trainer_notes) when is_binary(trainer_notes) do
    trimmed_notes = String.trim(trainer_notes)

    if trimmed_notes == "" do
      ""
    else
      "\nTrainer observations: #{trimmed_notes}"
    end
  end

  defp rest_day_name(1), do: "Mon"
  defp rest_day_name(2), do: "Tue"
  defp rest_day_name(3), do: "Wed"
  defp rest_day_name(4), do: "Thu"
  defp rest_day_name(5), do: "Fri"
  defp rest_day_name(6), do: "Sat"
  defp rest_day_name(7), do: "Sun"
  defp rest_day_name(day), do: "Day #{day}"

  defp log_parsed_plan_summary(%{program: program, workout_days: workout_days}) do
    exercise_count =
      workout_days
      |> Enum.map(&length(Map.get(&1, :exercises, [])))
      |> Enum.sum()

    Logger.info(
      "AI plan parsed successfully program_name=#{inspect(program.name)} total_weeks=#{program.total_weeks} workout_days=#{length(workout_days)} exercises=#{exercise_count} current_phase=#{program.current_phase} phase_name=#{inspect(program.phase_name)}"
    )
  end

  defp log_parse_failure(reason, json_string) do
    {head_preview, head_truncated?} = truncate_for_log(json_string, 800)
    tail_preview = tail_preview(json_string, 300)

    Logger.warning(
      "AI plan parse failed reason=#{inspect(reason)} response_chars=#{byte_size(json_string)} head_truncated=#{head_truncated?} head_preview=#{inspect(head_preview, printable_limit: :infinity, limit: :infinity)} tail_preview=#{inspect(tail_preview, printable_limit: :infinity, limit: :infinity)}"
    )
  end

  defp truncate_for_log(content, max_chars) when is_binary(content) and is_integer(max_chars) do
    if String.length(content) <= max_chars do
      {content, false}
    else
      {String.slice(content, 0, max_chars), true}
    end
  end

  defp tail_preview(content, max_chars) when is_binary(content) and is_integer(max_chars) do
    content_length = String.length(content)

    if content_length <= max_chars do
      content
    else
      String.slice(content, content_length - max_chars, max_chars)
    end
  end
end
