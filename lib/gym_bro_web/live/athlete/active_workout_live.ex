defmodule GymBroWeb.Athlete.ActiveWorkoutLive do
  use GymBroWeb, :live_view

  alias GymBro.{Onboarding, Training}

  @impl true
  def mount(%{"session_id" => session_id}, _session, socket) do
    current_user = socket.assigns.current_user

    case Onboarding.next_path(current_user) do
      "/" ->
        if connected?(socket) do
          Training.subscribe_to_workout(session_id)
          Training.subscribe_to_client_session(current_user.id)
        end

        {:ok,
         socket
         |> assign_session_data(current_user, session_id)
         |> assign(:page_title, "Active Workout")
         |> assign(:rest_timer, nil)
         |> assign(:trainer_message_toast, nil), layout: false}

      path ->
        {:ok, push_navigate(socket, to: path), layout: false}
    end
  end

  @impl true
  def handle_event("log_set", %{"exercise_id" => exercise_id, "exercise_log" => params}, socket) do
    session = socket.assigns.session
    exercise = find_exercise!(socket.assigns.session.workout_day.exercises, exercise_id)

    case Training.log_exercise_set(session, exercise, normalize_log_params(params)) do
      {:ok, _log} ->
        if is_integer(exercise.rest_seconds) and exercise.rest_seconds > 0 do
          Training.broadcast_workout_event(session.id, :rest_timer_started, %{
            exercise_id: exercise.id,
            exercise_name: exercise.name,
            owner_pid: self(),
            remaining_seconds: exercise.rest_seconds,
            total_seconds: exercise.rest_seconds
          })
        end

        {:noreply,
         socket
         |> assign_session_data(socket.assigns.current_user, session.id, exercise.id)
         |> put_flash(:info, "#{exercise.name} set logged.")}

      {:error, :exercise_not_in_session} ->
        {:noreply, put_flash(socket, :error, "That exercise does not belong to this workout.")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "We could not save that set. Check the values and try again.")}
    end
  end

  @impl true
  def handle_event("cancel_timer", _params, socket) do
    Training.broadcast_workout_event(socket.assigns.session.id, :rest_timer_cleared, %{})
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_exercise", %{"exercise_id" => exercise_id}, socket) do
    active_exercise_id =
      socket.assigns.session.workout_day.exercises
      |> choose_active_exercise_id(exercise_id)
      |> Kernel.||(socket.assigns.active_exercise_id)

    {:noreply, assign(socket, :active_exercise_id, active_exercise_id)}
  end

  @impl true
  def handle_event("complete_workout", _params, socket) do
    case Training.complete_workout_session(socket.assigns.session) do
      {:ok, _session} ->
        Training.broadcast_workout_event(socket.assigns.session.id, :rest_timer_cleared, %{})

        {:noreply,
         socket
         |> put_flash(:info, "Workout completed.")
         |> push_navigate(to: ~p"/workouts/#{socket.assigns.session.workout_day_id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "We could not complete that workout yet.")}
    end
  end

  @impl true
  def handle_info({:workout_event, :rest_timer_started, payload}, socket) do
    if payload.owner_pid == self() do
      Process.send_after(self(), {:rest_timer_tick, socket.assigns.session.id}, 1_000)
    end

    {:noreply, assign(socket, :rest_timer, Map.delete(payload, :owner_pid))}
  end

  def handle_info({:workout_event, :rest_timer_updated, payload}, socket) do
    {:noreply, assign(socket, :rest_timer, Map.delete(payload, :owner_pid))}
  end

  def handle_info({:workout_event, :rest_timer_completed, _payload}, socket) do
    {:noreply,
     socket
     |> push_event("workout:buzz", %{pattern: [180, 90, 180, 90, 260]})
     |> assign(:rest_timer, nil)
     |> put_flash(:info, "Rest timer complete.")}
  end

  def handle_info({:workout_event, :rest_timer_cleared, _payload}, socket) do
    {:noreply, assign(socket, :rest_timer, nil)}
  end

  def handle_info({:client_session_event, :trainer_message, payload}, socket) do
    toast = %{
      id: System.unique_integer([:positive]),
      message: Map.get(payload, :message) || Map.get(payload, "message"),
      trainer_name: Map.get(payload, :trainer_name) || Map.get(payload, "trainer_name") || "Coach"
    }

    Process.send_after(self(), {:clear_trainer_message_toast, toast.id}, 5_000)

    {:noreply,
     socket
     |> push_event("workout:buzz", %{pattern: [100, 60, 100]})
     |> assign(:trainer_message_toast, toast)}
  end

  def handle_info({:client_session_event, _event, _payload}, socket) do
    {:noreply, socket}
  end

  def handle_info({:clear_trainer_message_toast, toast_id}, socket) do
    case socket.assigns.trainer_message_toast do
      %{id: ^toast_id} -> {:noreply, assign(socket, :trainer_message_toast, nil)}
      _toast -> {:noreply, socket}
    end
  end

  def handle_info({:rest_timer_tick, session_id}, socket) do
    case socket.assigns.rest_timer do
      %{remaining_seconds: remaining_seconds} = rest_timer when remaining_seconds > 1 ->
        next_payload =
          rest_timer
          |> Map.put(:remaining_seconds, remaining_seconds - 1)
          |> Map.put(:owner_pid, self())

        Training.broadcast_workout_event(session_id, :rest_timer_updated, next_payload)
        Process.send_after(self(), {:rest_timer_tick, session_id}, 1_000)
        {:noreply, socket}

      %{remaining_seconds: 1} = rest_timer ->
        Training.broadcast_workout_event(session_id, :rest_timer_completed, %{
          exercise_id: rest_timer.exercise_id
        })

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="active-workout-screen" class="app-shell py-6" phx-hook="WorkoutFeedback">
      <.flash_group flash={@flash} />

      <div class="gb-grid">
        <div class="gb-grid__main space-y-6">
          <.callout :if={@trainer_message_toast} label="Coach note">
            <p class="type-h3 mb-1">{@trainer_message_toast.trainer_name}</p>
            <p class="type-body">{@trainer_message_toast.message}</p>
          </.callout>

          <div class="flex items-center justify-between">
            <.back navigate={~p"/workouts/#{@session.workout_day_id}"}>Day plan</.back>
            <span class="inline-flex items-center gap-2 rounded-pill border border-accent bg-accent-soft px-3 py-1 text-xs font-semibold text-accent">
              <span class="gb-live-dot" style="background: var(--accent);" /> LIVE
            </span>
          </div>

          <header class="flex items-end justify-between gap-4">
            <div>
              <p class="type-label inline-flex items-center gap-2">
                <span class="gb-label-dot" />In session
              </p>
              <h1 class="mt-2 type-h1 gb-heading-accent">
                {@session.workout_day.day_label || "Workout"}
              </h1>
              <p class="mt-3 type-body-sm inline-flex items-center gap-1.5">
                <.icon name="hero-calendar-mini" class="h-3.5 w-3.5 text-accent" />
                Week {@session.workout_day.week_number} · Day {@session.workout_day.day_number} · started {started_label(
                  @session.started_at
                )}
              </p>
            </div>
            <div class="text-right">
              <p class="type-label inline-flex items-center gap-1.5">
                <.icon name="hero-clock-mini" class="h-3.5 w-3.5 text-accent" /> Elapsed
              </p>
              <p class="mt-1 type-mono-stat">{elapsed_label(@session.started_at)}</p>
            </div>
          </header>

          <section :if={@rest_timer}>
            <.callout label="Rest timer">
              <div class="flex items-center justify-between gap-4">
                <div>
                  <p class="type-mono-stat" style="font-size: 32px; line-height: 36px;">
                    {@rest_timer.remaining_seconds}s
                  </p>
                  <p class="mt-1 type-body-sm">
                    Recover, then back into {@rest_timer.exercise_name}.
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="cancel_timer"
                  class="gb-btn gb-btn--secondary gb-btn--sm"
                >
                  Clear
                </button>
              </div>
            </.callout>
          </section>

          <section class="space-y-3">
            <section
              :for={exercise <- @session.workout_day.exercises}
              id={"exercise-panel-#{exercise.id}"}
              class={[
                "gb-card transition-all duration-200",
                active_exercise?(@active_exercise_id, exercise.id) &&
                  "gb-card--accent shadow-[var(--shadow-md)]"
              ]}
            >
              <button
                id={"exercise-toggle-#{exercise.id}"}
                type="button"
                phx-click="select_exercise"
                phx-value-exercise_id={exercise.id}
                aria-controls={"exercise-body-#{exercise.id}"}
                aria-expanded={to_string(active_exercise?(@active_exercise_id, exercise.id))}
                class="flex w-full items-start justify-between gap-4 text-left"
              >
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2">
                    <span class="grid h-6 w-6 flex-none place-items-center rounded-pill bg-accent-soft text-xs font-bold text-accent">
                      {exercise.position}
                    </span>
                    <p class="type-label">Exercise</p>
                    <span
                      :if={active_exercise?(@active_exercise_id, exercise.id)}
                      class="gb-pill gb-pill--accent"
                    >
                      Active
                    </span>
                  </div>
                  <h2 class="mt-2 type-h2">{exercise.name}</h2>
                  <p class="mt-1 type-body-sm">{exercise_target(exercise)}</p>
                  <p :if={exercise.progression_hint} class="mt-2 type-body-sm text-text-muted">
                    {exercise.progression_hint}
                  </p>
                  <p class="mt-3 type-body-sm">
                    {exercise_progress_label(@session.exercise_logs, exercise)}
                  </p>
                </div>
                <div class="flex flex-none items-start gap-3">
                  <div class="text-right">
                    <p class="type-label inline-flex items-center gap-1.5">
                      <.icon name="hero-forward-mini" class="h-3.5 w-3.5 text-accent" /> Next set
                    </p>
                    <p class="mt-1 type-mono-stat">
                      {next_set_number(@session.exercise_logs, exercise.id)}
                    </p>
                  </div>
                  <.icon
                    name={
                      if active_exercise?(@active_exercise_id, exercise.id),
                        do: "hero-chevron-up-mini",
                        else: "hero-chevron-down-mini"
                    }
                    class="mt-1 h-5 w-5 text-text-subtle"
                  />
                </div>
              </button>

              <div
                :if={active_exercise?(@active_exercise_id, exercise.id)}
                id={"exercise-body-#{exercise.id}"}
                class="mt-5 space-y-4 border-t border-border pt-4"
              >
                <ul
                  :if={logs_for_exercise(@session.exercise_logs, exercise.id) != []}
                  class="divide-y divide-border border-y border-border"
                >
                  <li
                    :for={log <- logs_for_exercise(@session.exercise_logs, exercise.id)}
                    class="flex items-center justify-between py-3 text-sm"
                  >
                    <div>
                      <span class="font-medium text-text">Set {log.set_number}</span>
                      <span class="ml-2 text-text-muted">{log_description(log, exercise)}</span>
                    </div>
                  </li>
                </ul>

                <form id={"set-log-form-#{exercise.id}"} phx-submit="log_set" class="space-y-3">
                  <input type="hidden" name="exercise_id" value={exercise.id} />

                  <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
                    <div>
                      <label class="type-label" for={"reps-#{exercise.id}"}>Reps</label>
                      <input
                        id={"reps-#{exercise.id}"}
                        type="number"
                        min="0"
                        name="exercise_log[reps_completed]"
                        class="gb-input gb-input--stat mt-2"
                      />
                    </div>
                    <div>
                      <label class="type-label" for={"weight-#{exercise.id}"}>Weight kg</label>
                      <input
                        id={"weight-#{exercise.id}"}
                        type="number"
                        min="0"
                        step="0.5"
                        name="exercise_log[weight_kg]"
                        value={default_weight(exercise)}
                        class="gb-input gb-input--stat mt-2"
                      />
                    </div>
                  </div>

                  <button type="submit" class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block">
                    <.icon name="hero-check-solid" class="h-4 w-4" />
                    Log set {next_set_number(@session.exercise_logs, exercise.id)}
                  </button>
                </form>
              </div>
            </section>
          </section>
        </div>

        <aside class="gb-grid__side md:sticky md:top-6 md:self-start gb-card gb-card--accent">
          <.section_head icon="hero-trophy-mini">Workout progress</.section_head>
          <p class="mt-2 type-h2">{length(@session.exercise_logs)} sets logged</p>

          <button
            id="complete-workout-button"
            type="button"
            phx-click="complete_workout"
            class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block mt-4"
          >
            <.icon name="hero-flag-solid" class="h-4 w-4" /> Complete workout
          </button>
        </aside>
      </div>
    </div>
    """
  end

  defp assign_session_data(socket, current_user, session_id, preferred_active_exercise_id \\ nil) do
    session = Training.get_workout_session_for_user!(current_user.id, session_id)

    active_exercise_id =
      resolve_active_exercise_id(
        session,
        preferred_active_exercise_id || socket.assigns[:active_exercise_id]
      )

    socket
    |> assign(:session, session)
    |> assign(:active_exercise_id, active_exercise_id)
  end

  defp normalize_log_params(params) do
    params
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp find_exercise!(exercises, exercise_id) do
    Enum.find(exercises, &(to_string(&1.id) == to_string(exercise_id))) ||
      raise Ecto.NoResultsError, queryable: Training
  end

  defp logs_for_exercise(exercise_logs, exercise_id) do
    exercise_logs
    |> Enum.filter(&(&1.exercise_id == exercise_id))
    |> Enum.sort_by(&{&1.set_number, &1.inserted_at})
  end

  defp next_set_number(exercise_logs, exercise_id) do
    exercise_logs
    |> logs_for_exercise(exercise_id)
    |> List.last()
    |> case do
      nil -> 1
      log -> log.set_number + 1
    end
  end

  defp exercise_target(exercise) do
    [
      exercise.sets && "#{exercise.sets} sets",
      exercise.reps && "#{exercise.reps} reps",
      display_weight(exercise) && "#{format_number(display_weight(exercise))} kg"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" • ")
  end

  defp active_exercise?(active_exercise_id, exercise_id),
    do: to_string(active_exercise_id) == to_string(exercise_id)

  defp exercise_progress_label(exercise_logs, exercise) do
    completed_sets = exercise_logs |> logs_for_exercise(exercise.id) |> length()

    cond do
      completed_sets == 0 ->
        "Ready to start"

      is_integer(exercise.sets) ->
        "#{completed_sets} of #{exercise.sets} sets logged"

      true ->
        "#{completed_sets} sets logged"
    end
  end

  defp log_description(log, exercise) do
    segments =
      [
        if(log.reps_completed, do: "#{log.reps_completed} reps"),
        if(log.weight_kg, do: "#{format_number(log.weight_kg)} kg"),
        if(log.is_personal_record, do: "PR")
      ]
      |> Enum.reject(&is_nil/1)

    if segments == [], do: exercise_target(exercise), else: Enum.join(segments, " • ")
  end

  defp started_label(nil), do: "just now"
  defp started_label(started_at), do: Calendar.strftime(started_at, "%H:%M")

  defp elapsed_label(nil), do: "--"

  defp elapsed_label(started_at) do
    elapsed_seconds = max(DateTime.diff(DateTime.utc_now(), started_at, :second), 1)
    minutes = div(elapsed_seconds, 60)
    seconds = rem(elapsed_seconds, 60)
    "#{minutes}m #{String.pad_leading(Integer.to_string(seconds), 2, "0")}s"
  end

  defp default_weight(exercise) do
    case display_weight(exercise) do
      nil -> ""
      weight -> format_number(weight)
    end
  end

  defp display_weight(%{recommended_weight_kg: recommended_weight_kg})
       when is_number(recommended_weight_kg),
       do: recommended_weight_kg

  defp display_weight(%{weight_kg: weight_kg}), do: weight_kg

  defp resolve_active_exercise_id(session, preferred_active_exercise_id) do
    exercises = session.workout_day.exercises

    cond do
      preferred_active_exercise_id &&
          exercise_still_in_progress?(session, preferred_active_exercise_id) ->
        choose_active_exercise_id(exercises, preferred_active_exercise_id)

      preferred_active_exercise_id ->
        next_incomplete_exercise_id(session, preferred_active_exercise_id) ||
          choose_default_active_exercise_id(session)

      true ->
        choose_default_active_exercise_id(session)
    end
  end

  defp choose_default_active_exercise_id(session) do
    next_incomplete_exercise_id(session) ||
      case session.workout_day.exercises do
        [exercise | _rest] -> exercise.id
        [] -> nil
      end
  end

  defp next_incomplete_exercise_id(session, preferred_active_exercise_id \\ nil) do
    exercises = session.workout_day.exercises

    ordered_exercises =
      case choose_active_exercise_id(exercises, preferred_active_exercise_id) do
        nil ->
          exercises

        active_exercise_id ->
          {before_active, from_active} =
            Enum.split_while(exercises, &(to_string(&1.id) != to_string(active_exercise_id)))

          case from_active do
            [_active | remaining] -> remaining ++ before_active
            [] -> exercises
          end
      end

    ordered_exercises
    |> Enum.find(&(not exercise_completed?(session, &1)))
    |> case do
      nil -> nil
      exercise -> exercise.id
    end
  end

  defp exercise_still_in_progress?(session, exercise_id) do
    case Enum.find(session.workout_day.exercises, &(to_string(&1.id) == to_string(exercise_id))) do
      nil -> false
      exercise -> not exercise_completed?(session, exercise)
    end
  end

  defp exercise_completed?(session, exercise) do
    prescribed_sets = exercise.sets || 1_000_000
    completed_sets = session.exercise_logs |> logs_for_exercise(exercise.id) |> length()
    completed_sets >= prescribed_sets
  end

  defp choose_active_exercise_id(exercises, exercise_id) do
    Enum.find_value(exercises, fn exercise ->
      if to_string(exercise.id) == to_string(exercise_id), do: exercise.id
    end)
  end

  defp format_number(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)
  defp format_number(value), do: to_string(value)
end
