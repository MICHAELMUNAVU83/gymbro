defmodule GymBroWeb.Athlete.WorkoutDetailLive do
  use GymBroWeb, :live_view

  alias GymBro.{Onboarding, Programs, Training}

  @impl true
  def mount(%{"id" => workout_day_id}, _session, socket) do
    current_user = socket.assigns.current_user

    case Onboarding.next_path(current_user) do
      "/" ->
        {:ok,
         socket
         |> assign_workout_day(current_user, workout_day_id)
         |> assign(:active_nav, :workouts)
         |> assign(:page_title, "Workout Day")}

      path ->
        {:ok, push_navigate(socket, to: path), layout: false}
    end
  end

  @impl true
  def handle_event("start", _params, socket) do
    workout_day = socket.assigns.workout_day
    current_user = socket.assigns.current_user

    case Training.get_or_start_workout_session(current_user.id, workout_day.id) do
      {:ok, session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workout session ready.")
         |> push_navigate(to: ~p"/workouts/session/#{session.id}")}

      {:error, {:active_session_exists, session}} ->
        {:noreply,
         socket
         |> put_flash(:info, "You already have an active workout. Jumping back in.")
         |> push_navigate(to: ~p"/workouts/session/#{session.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "We could not start this workout yet.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="gb-grid">
      <div class="gb-grid__main space-y-6">
        <div class="flex items-center justify-between">
          <.back navigate={~p"/workouts"}>Back</.back>
          <p class="type-label inline-flex items-center gap-1.5">
            <.icon name="hero-calendar-mini" class="h-3.5 w-3.5 text-accent" />
            Week {@workout_day.week_number} · Day {@workout_day.day_number}
          </p>
        </div>

        <header>
          <p class="type-label inline-flex items-center gap-2">
            <span class="gb-label-dot" />Today's session
          </p>
          <h1 class="mt-2 type-h1 gb-heading-accent">
            {@workout_day.day_label || "Workout day"}
          </h1>
          <p class="mt-3 type-body-sm">{detail_subtitle(@workout_day)}</p>
        </header>

        <.stat_row>
          <:item label="Duration" icon="hero-clock-mini">
            {format_minutes(@workout_day.estimated_duration_min)}
          </:item>
          <:item label="Exercises" icon="hero-list-bullet-mini">
            {length(@workout_day.exercises)}
          </:item>
          <:item label="Status" icon="hero-flag-mini">
            {status_label(@workout_day, @active_session, @completed_session)}
          </:item>
        </.stat_row>

        <section :if={@completed_session} class="space-y-1">
          <.section_head icon="hero-check-circle-mini">Last completion</.section_head>
          <div class="flex items-end justify-between gap-4 mt-2">
            <div>
              <p class="type-h2">{format_datetime(@completed_session.completed_at)}</p>
              <p class="mt-1 type-body-sm">
                Finished in {format_duration(@completed_session.duration_seconds)}
              </p>
            </div>
            <p class="max-w-[18ch] text-right type-body-sm">
              {@completed_session.notes ||
                "Ready whenever you want to repeat it."}
            </p>
          </div>
        </section>

        <hr class="gb-divider" />

        <section>
          <.section_head icon="hero-fire-mini">Exercise plan</.section_head>
          <h2 class="mt-2 type-h2">
            {if @workout_day.is_rest_day, do: "Recovery focus", else: "Move through the full list"}
          </h2>

          <div :if={@workout_day.is_rest_day} class="mt-4 type-body text-text-muted">
            A programmed recovery day. Use it for light movement, mobility, and resetting before the next session.
          </div>

          <ol
            :if={not @workout_day.is_rest_day}
            class="mt-6 divide-y divide-border border-y-2 border-border"
          >
            <li :for={exercise <- @workout_day.exercises} class="py-4">
              <div class="flex items-start justify-between gap-4">
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <span class="grid h-6 w-6 flex-none place-items-center rounded-pill bg-accent-soft text-xs font-bold text-accent">
                      {exercise.position}
                    </span>
                    <h3 class="type-h3">{exercise.name}</h3>
                  </div>
                  <p class="mt-2 type-body-sm">{exercise_summary(exercise)}</p>
                  <p :if={exercise.progression_hint} class="mt-2 type-body-sm text-text-muted">
                    {exercise.progression_hint}
                  </p>
                  <p :if={exercise.notes} class="mt-2 type-body-sm">{exercise.notes}</p>
                  <p
                    :if={exercise.visual_guide}
                    class="mt-2 type-body-sm inline-flex items-start gap-1.5 text-text-muted"
                  >
                    <.icon name="hero-eye-mini" class="h-3.5 w-3.5 mt-0.5 text-accent" />
                    How to do it: {exercise.visual_guide}
                  </p>
                  <p
                    :if={exercise.trainer_notes}
                    class="mt-2 type-body-sm inline-flex items-start gap-1.5"
                    style="color: var(--accent)"
                  >
                    <.icon name="hero-megaphone-mini" class="h-3.5 w-3.5 mt-0.5" />
                    Trainer: {exercise.trainer_notes}
                  </p>
                </div>
                <div class="text-right">
                  <p class="type-label inline-flex items-center gap-1.5">
                    <.icon name="hero-pause-circle-mini" class="h-3.5 w-3.5 text-accent" /> Rest
                  </p>
                  <p class="mt-1 type-mono-stat">{exercise_rest_label(exercise)}</p>
                </div>
              </div>
            </li>
          </ol>
        </section>
      </div>

      <aside class="gb-grid__side space-y-6 md:sticky md:top-6 md:self-start">
        <section :if={not @workout_day.is_rest_day} class="gb-card gb-card--accent">
          <.section_head icon="hero-bolt-mini">Session control</.section_head>
          <h2 class="mt-2 type-h2">
            {session_cta_heading(@active_session, @workout_day)}
          </h2>
          <p class="mt-2 type-body-sm">{session_cta_copy(@active_session, @workout_day)}</p>

          <button
            id="start-workout-button"
            type="button"
            phx-click="start"
            class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block mt-4"
          >
            <.icon name="hero-play-solid" class="h-4 w-4" />
            {session_cta_label(@active_session, @workout_day)}
          </button>
        </section>

        <.callout :if={@workout_day.trainer_notes} label="Trainer notes">
          {@workout_day.trainer_notes}
        </.callout>
      </aside>
    </div>
    """
  end

  defp assign_workout_day(socket, current_user, workout_day_id) do
    workout_day =
      current_user.id
      |> Programs.get_workout_day_for_user!(workout_day_id)
      |> then(&Training.apply_progression_recommendations_to_workout_day(current_user.id, &1))

    active_session = Training.get_active_workout_session_for_user(current_user.id)

    completed_session =
      Training.latest_completed_workout_session_for_day(current_user.id, workout_day.id)

    socket
    |> assign(:active_session, active_session)
    |> assign(:completed_session, completed_session)
    |> assign(:workout_day, workout_day)
  end

  defp detail_subtitle(workout_day) do
    workout_day.muscle_groups
    |> List.wrap()
    |> case do
      [] -> "A focused session built to keep momentum moving."
      groups -> Enum.map_join(groups, " • ", &titleize/1)
    end
  end

  defp status_label(%{is_rest_day: true}, _active_session, _completed_session), do: "Rest"

  defp status_label(workout_day, %{workout_day_id: workout_day_id}, _completed_session)
       when workout_day.id == workout_day_id do
    "Active"
  end

  defp status_label(_workout_day, _active_session, nil), do: "Ready"
  defp status_label(_workout_day, _active_session, _completed_session), do: "Completed"

  defp session_cta_heading(%{workout_day_id: workout_day_id}, workout_day)
       when workout_day_id == workout_day.id do
    "Your session is already live."
  end

  defp session_cta_heading(%{} = _active_session, _workout_day),
    do: "Another workout is still active."

  defp session_cta_heading(nil, _workout_day), do: "Ready to train?"

  defp session_cta_copy(%{workout_day_id: workout_day_id}, workout_day)
       when workout_day_id == workout_day.id do
    "Jump back into your set logger, timer, and exercise progress."
  end

  defp session_cta_copy(%{} = _active_session, _workout_day) do
    "You can only keep one active session open at a time, so the button will take you back to the current one."
  end

  defp session_cta_copy(nil, _workout_day) do
    "Spin up the workout logger and track each set in real time."
  end

  defp session_cta_label(%{workout_day_id: workout_day_id}, workout_day)
       when workout_day_id == workout_day.id do
    "Resume workout"
  end

  defp session_cta_label(%{} = _active_session, _workout_day), do: "Open active session"
  defp session_cta_label(nil, _workout_day), do: "Start workout"

  defp exercise_summary(exercise) do
    segments =
      [
        if(exercise.sets, do: "#{exercise.sets} sets"),
        if(exercise.reps, do: "#{exercise.reps} reps"),
        if(display_weight(exercise), do: "#{format_number(display_weight(exercise))} kg")
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(segments, " • ")
  end

  defp display_weight(%{recommended_weight_kg: recommended_weight_kg})
       when is_number(recommended_weight_kg),
       do: recommended_weight_kg

  defp display_weight(%{weight_kg: weight_kg}), do: weight_kg

  defp exercise_rest_label(%{is_timed: true, duration_seconds: duration_seconds})
       when is_integer(duration_seconds) do
    "#{duration_seconds}s"
  end

  defp exercise_rest_label(exercise) when is_integer(exercise.rest_seconds),
    do: "#{exercise.rest_seconds}s"

  defp exercise_rest_label(_exercise), do: "--"

  defp format_minutes(nil), do: "--"
  defp format_minutes(value), do: "#{value} min"

  defp format_duration(nil), do: "--"
  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    remainder = rem(seconds, 60)
    "#{minutes}m #{remainder}s"
  end

  defp format_datetime(nil), do: "Not finished yet"

  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %-d, %H:%M")
  end

  defp format_number(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)
  defp format_number(value), do: to_string(value)

  defp titleize(value) do
    value
    |> to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
