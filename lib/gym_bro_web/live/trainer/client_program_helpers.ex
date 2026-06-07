defmodule GymBroWeb.Trainer.ClientProgramHelpers do
  @moduledoc """
  Shared presentation helpers for the trainer-facing client program screens
  (client detail, the per-day workout page, and the regenerate/config page).
  """

  @doc "Groups workout days into `{week_number, [days]}` tuples sorted for display."
  def group_days_by_week(program_workout_days) do
    program_workout_days
    |> Enum.group_by(& &1.week_number)
    |> Enum.map(fn {week_number, days} ->
      {week_number, Enum.sort_by(days, & &1.day_number)}
    end)
    |> Enum.sort_by(fn {week_number, _days} -> week_number end)
  end

  @doc "Short summary of a week's training load for the week header."
  def week_summary(week_days) do
    training_days = Enum.count(week_days, &(not &1.is_rest_day))

    case training_days do
      0 -> "Recovery week"
      1 -> "1 training day"
      count -> "#{count} training days"
    end
  end

  def workout_day_subtitle(%{is_rest_day: true}), do: "Rest and recovery"

  def workout_day_subtitle(workout_day) do
    workout_day.muscle_groups
    |> List.wrap()
    |> case do
      [] -> "#{length(workout_day.exercises)} exercises"
      groups -> Enum.map_join(groups, " • ", &titleize/1)
    end
  end

  def detail_subtitle(workout_day) do
    workout_day.muscle_groups
    |> List.wrap()
    |> case do
      [] -> "A focused session built to keep momentum moving."
      groups -> Enum.map_join(groups, " • ", &titleize/1)
    end
  end

  def trainer_status_label(%{is_rest_day: true}, _live_session, _completed_session), do: "Rest"

  def trainer_status_label(workout_day, %{workout_day_id: workout_day_id}, _completed_session)
      when workout_day.id == workout_day_id do
    "Active"
  end

  def trainer_status_label(_workout_day, _live_session, nil), do: "Ready"
  def trainer_status_label(_workout_day, _live_session, _completed_session), do: "Completed"

  def trainer_session_cta_heading(%{workout_day_id: workout_day_id}, workout_day)
      when workout_day_id == workout_day.id do
    "This athlete is already in session."
  end

  def trainer_session_cta_heading(%{} = _live_session, _workout_day),
    do: "Another workout is still active."

  def trainer_session_cta_heading(nil, _workout_day), do: "Ready to coach this workout?"

  def trainer_session_cta_copy(%{workout_day_id: workout_day_id}, workout_day)
      when workout_day_id == workout_day.id do
    "Open the live logger and track each set as it lands."
  end

  def trainer_session_cta_copy(%{} = _live_session, _workout_day) do
    "Only one active workout can run at a time, so this will take you back to the athlete's current session."
  end

  def trainer_session_cta_copy(nil, _workout_day) do
    "Spin up the same workout logger the athlete uses so you can coach the set flow in real time."
  end

  def trainer_session_cta_label(%{workout_day_id: workout_day_id}, workout_day)
      when workout_day_id == workout_day.id do
    "Resume live workout"
  end

  def trainer_session_cta_label(%{} = _live_session, _workout_day), do: "Open active session"
  def trainer_session_cta_label(nil, _workout_day), do: "Start workout"

  def selected_session_matches_day?(%{workout_day_id: workout_day_id}, workout_day),
    do: to_string(workout_day_id) == to_string(workout_day.id)

  def selected_session_matches_day?(_live_session, _workout_day), do: false

  def format_minutes(nil), do: "--"
  def format_minutes(minutes), do: "#{minutes} min"

  def format_duration(nil), do: "--"

  def format_duration(duration_seconds) when is_integer(duration_seconds) do
    minutes = div(duration_seconds, 60)
    seconds = rem(duration_seconds, 60)
    "#{minutes}m #{String.pad_leading(Integer.to_string(seconds), 2, "0")}s"
  end

  def format_datetime(nil), do: "--"
  def format_datetime(datetime), do: Calendar.strftime(datetime, "%b %-d, %Y %H:%M")

  def exercise_rest_label(%{rest_seconds: rest_seconds}) when is_integer(rest_seconds),
    do: "#{rest_seconds}s"

  def exercise_rest_label(_exercise), do: "—"

  def exercise_summary(exercise) do
    [
      if(exercise.sets, do: "#{exercise.sets} sets"),
      if(exercise.reps, do: "#{exercise.reps} reps"),
      if(exercise.weight_kg, do: "#{format_weight_number(exercise.weight_kg)} kg"),
      if(exercise.rest_seconds, do: "#{exercise.rest_seconds}s rest"),
      timed_label(exercise)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" • ")
  end

  defp timed_label(%{is_timed: true, duration_seconds: duration_seconds})
       when is_integer(duration_seconds),
       do: "#{duration_seconds}s timed"

  defp timed_label(_exercise), do: nil

  def override_summary(override) do
    [
      if(override.sets, do: "#{override.sets} sets"),
      if(override.reps, do: "#{override.reps} reps"),
      if(override.weight_kg, do: "#{format_weight_number(override.weight_kg)} kg"),
      override.notes
    ]
    |> Enum.reject(fn value -> is_nil(value) or value == "" end)
    |> Enum.join(" • ")
  end

  def format_weight_number(nil), do: "--"
  def format_weight_number(value) when is_integer(value), do: "#{value}.0"

  def format_weight_number(value) when is_float(value),
    do: :erlang.float_to_binary(value, decimals: 1)

  def titleize(value) do
    value
    |> to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  def exercise_form_title(%{mode: :new}), do: "Add an exercise"
  def exercise_form_title(%{mode: :edit}), do: "Edit exercise"
  def exercise_form_title(_editor), do: "Exercise"

  def exercise_submit_label(%{mode: :new}), do: "Add exercise"
  def exercise_submit_label(%{mode: :edit}), do: "Save exercise"
  def exercise_submit_label(_editor), do: "Save"

  def success_message(:new), do: "Exercise added to the client day."
  def success_message(:edit), do: "Exercise update saved."

  def program_title(nil), do: "No program yet"
  def program_title(program), do: program.name || "Untitled program"

  def program_summary(nil),
    do: "Generate a program from trainer notes to get this client moving."

  def program_summary(program) do
    [
      program.description,
      "#{length(program.workout_days)} scheduled days",
      source_label(program.source)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" • ")
  end

  defp source_label(nil), do: nil

  defp source_label(source),
    do: source |> to_string() |> String.replace("_", " ") |> String.upcase()

  def program_status_label(nil), do: "Missing"
  def program_status_label(program), do: String.capitalize(program.status)

  def program_status_class(nil), do: "gb-pill"

  def program_status_class(program) do
    case program.status do
      "active" -> "gb-pill gb-pill--success"
      "paused" -> "gb-pill gb-pill--warning"
      _ -> "gb-pill"
    end
  end

  def display_name(email) do
    email
    |> to_string()
    |> String.split("@")
    |> List.first()
    |> String.replace(~r/[._-]+/u, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  def regeneration_error(:missing_profile),
    do: "This client needs a completed profile before AI can build a plan."

  def regeneration_error(:missing_openai_api_key),
    do: "OpenAI is not configured in this environment yet."

  def regeneration_error(:openai_timeout),
    do: "Plan generation timed out. Please try again."

  def regeneration_error(:openai_rate_limited),
    do: "OpenAI is busy right now. Please try regenerating again in a moment."

  def regeneration_error(_reason),
    do: "We could not regenerate the plan yet. Please try again."
end
