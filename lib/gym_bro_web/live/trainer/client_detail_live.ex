defmodule GymBroWeb.Trainer.ClientDetailLive do
  use GymBroWeb, :live_view

  alias GymBro.{Onboarding, Profiles, Programs, Trainer, Training}

  @chart_width 320.0
  @chart_height 160.0
  @chart_padding 16.0
  @tabs ~w(stats program photos prs)
  @trainer_message_max_length 180

  @impl true
  def mount(%{"client_id" => client_id} = params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = Profiles.get_trainer_profile_by_user(current_user.id)
    active_tab = normalize_tab(Map.get(params, "tab", "stats"))

    cond do
      is_nil(profile) ->
        {:ok, push_navigate(socket, to: Onboarding.welcome_path(current_user)), layout: false}

      true ->
        case Trainer.get_managed_client_detail(current_user.id, client_id) do
          {:ok, detail} ->
            if connected?(socket) do
              Training.subscribe_to_client_session(detail.client.id)
            end

            {:ok,
             socket
             |> assign(:profile, profile)
             |> assign(:tabs, @tabs)
             |> assign(:active_nav, :clients)
             |> assign(:page_title, detail.client.email)
             |> assign(:active_tab, active_tab)
             |> assign(:live_active_exercise_id, nil)
             |> assign(:live_message_form, live_message_form(""))
             |> assign(:rest_timer, nil)
             |> assign(:elapsed_label, "--")
             |> assign(:tracked_workout_session_id, nil)
             |> assign_client_detail(detail)
             |> assign_live_session(detail.client.id), layout: {GymBroWeb.Layouts, :trainer_app}}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "That client could not be found in your roster.")
             |> push_navigate(to: ~p"/trainer/clients"), layout: false}
        end
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, normalize_tab(tab))}
  end

  def handle_event("send_live_message", %{"live_message" => %{"message" => message}}, socket) do
    trimmed_message = String.trim(message || "")

    cond do
      is_nil(socket.assigns.live_session) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Your client needs to be in an active session before you can send a live note."
         )}

      trimmed_message == "" ->
        {:noreply,
         socket
         |> assign(:live_message_form, live_message_form(message || ""))
         |> put_flash(:error, "Write a short note before sending it.")}

      String.length(trimmed_message) > @trainer_message_max_length ->
        {:noreply,
         socket
         |> assign(:live_message_form, live_message_form(trimmed_message))
         |> put_flash(
           :error,
           "Keep live notes under #{@trainer_message_max_length} characters."
         )}

      true ->
        Training.broadcast_client_session_event(
          socket.assigns.detail.client.id,
          :trainer_message,
          %{
            message: trimmed_message,
            trainer_name: trainer_display_name(socket.assigns.current_user)
          }
        )

        {:noreply,
         socket
         |> assign(:live_message_form, live_message_form(""))
         |> put_flash(:info, "Coach note sent.")}
    end
  end

  def handle_event("select_live_exercise", %{"exercise_id" => exercise_id}, socket) do
    active_exercise_id =
      socket.assigns.live_session.workout_day.exercises
      |> choose_active_exercise_id(exercise_id)
      |> Kernel.||(socket.assigns.live_active_exercise_id)

    {:noreply, assign(socket, :live_active_exercise_id, active_exercise_id)}
  end

  def handle_event(
        "log_live_set",
        %{"exercise_id" => exercise_id, "exercise_log" => params},
        socket
      ) do
    trainer_id = socket.assigns.current_user.id
    client_id = socket.assigns.detail.client.id
    session = socket.assigns.live_session
    exercise = find_exercise!(session.workout_day.exercises, exercise_id)

    case Trainer.log_client_exercise_set(
           trainer_id,
           client_id,
           session.id,
           exercise_id,
           normalize_log_params(params)
         ) do
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
         |> refresh_client_view(exercise.id)
         |> put_flash(:info, "#{exercise.name} set logged.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "This client is not currently editable.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> refresh_client_view()
         |> put_flash(:error, "That exercise is no longer available.")}

      {:error, :exercise_not_in_session} ->
        {:noreply, put_flash(socket, :error, "That exercise does not belong to this workout.")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "We could not save that set. Check the values and try again.")}
    end
  end

  def handle_event("cancel_timer", _params, socket) do
    if socket.assigns.live_session do
      Training.broadcast_workout_event(socket.assigns.live_session.id, :rest_timer_cleared, %{})
    end

    {:noreply, socket}
  end

  def handle_event("complete_live_workout", _params, socket) do
    trainer_id = socket.assigns.current_user.id
    client_id = socket.assigns.detail.client.id
    session = socket.assigns.live_session

    case Trainer.complete_client_workout_session(trainer_id, client_id, session.id) do
      {:ok, _session} ->
        Training.broadcast_workout_event(session.id, :rest_timer_cleared, %{})

        {:noreply,
         socket
         |> refresh_client_view()
         |> put_flash(:info, "Workout completed.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "This client is not currently editable.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> refresh_client_view()
         |> put_flash(:error, "That workout session is no longer available.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "We could not complete that workout yet.")}
    end
  end

  @impl true
  def handle_info({:client_session_event, _event, _payload}, socket) do
    {:noreply, refresh_client_view(socket)}
  end

  def handle_info({:workout_event, :rest_timer_started, payload}, socket) do
    if payload.owner_pid == self() do
      Process.send_after(self(), {:rest_timer_tick, socket.assigns.live_session.id}, 1_000)
    end

    {:noreply, assign(socket, :rest_timer, Map.delete(payload, :owner_pid))}
  end

  def handle_info({:workout_event, :rest_timer_updated, payload}, socket) do
    {:noreply, assign(socket, :rest_timer, Map.delete(payload, :owner_pid))}
  end

  def handle_info({:workout_event, :rest_timer_completed, _payload}, socket) do
    {:noreply,
     socket
     |> assign(:rest_timer, nil)
     |> put_flash(:info, "Rest timer complete.")}
  end

  def handle_info({:workout_event, :rest_timer_cleared, _payload}, socket) do
    {:noreply, assign(socket, :rest_timer, nil)}
  end

  def handle_info({:workout_event, :elapsed_tick, payload}, socket) do
    elapsed_seconds = Map.get(payload, :elapsed_seconds) || Map.get(payload, "elapsed_seconds")
    started_at = Map.get(payload, :started_at) || Map.get(payload, "started_at")

    label =
      if is_integer(elapsed_seconds) do
        elapsed_label(elapsed_seconds)
      else
        elapsed_label(started_at)
      end

    {:noreply, assign(socket, :elapsed_label, label)}
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
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <.back navigate={~p"/trainer/clients"}>All clients</.back>
        <span class={relationship_badge_class(@detail.relationship.status)}>
          {@detail.relationship.status}
        </span>
      </div>

      <header>
        <p class="type-label">Client file</p>
        <h1 class="mt-2 truncate type-h1">{display_name(@detail.client.email)}</h1>
        <p class="mt-1 truncate type-body-sm">{@detail.client.email}</p>
        <p class="mt-3 max-w-[60ch] type-body text-text-muted">
          {@detail.relationship.notes ||
            "No relationship notes yet. Use this file to tune programming, track progress, and keep all coaching context together."}
        </p>
      </header>

      <.stat_row>
        <:item label="Goal">{goal_label(@detail.profile)}</:item>
        <:item label="Weight">{format_weight(weight_value(@detail))}</:item>
        <:item label="PRs">{length(@detail.personal_records)}</:item>
      </.stat_row>

      <nav class="grid grid-cols-4 gap-2 border-b border-border">
        <button
          :for={tab <- @tabs}
          type="button"
          phx-click="switch_tab"
          phx-value-tab={tab}
          class={tab_button_class(tab, @active_tab)}
        >
          {tab_label(tab)}
        </button>
      </nav>

      <section class="space-y-6">
        <header class="flex items-start justify-between gap-4">
          <div>
            <p class="type-label inline-flex items-center gap-2">
              <span :if={@live_session} class="gb-live-dot" /> Live session
            </p>
            <h2 class="mt-2 type-h2">
              {if @live_session,
                do: "#{live_session_title(@live_session)} in progress",
                else: "Waiting for a check-in"}
            </h2>
            <p class="mt-2 type-body-sm">
              {if @live_session,
                do:
                  "Start, guide, and track the athlete's sets here with the same session flow they use.",
                else:
                  "As soon as this athlete starts a workout, their session and logged sets will appear here."}
            </p>
          </div>
          <div :if={@live_session} class="text-right">
            <p class="type-label">Sets logged</p>
            <p class="mt-1 type-mono-stat">{live_session_total_sets(@live_session)}</p>
            <p class="mt-1 type-body-sm">Elapsed {@elapsed_label}</p>
          </div>
        </header>

        <.form
          id="live-message-form"
          for={@live_message_form}
          phx-submit="send_live_message"
          class="space-y-3"
        >
          <.input
            field={@live_message_form[:message]}
            type="textarea"
            label="Send a live coach note"
            placeholder="Example: Slow the eccentric, keep your ribs down, and stay one rep shy of failure."
          />
          <button
            type="submit"
            class="gb-btn gb-btn--primary gb-btn--block"
            disabled={is_nil(@live_session)}
          >
            Send live note
          </button>
        </.form>

        <div :if={@rest_timer} class="gb-card gb-card--accent">
          <p class="type-label">Rest timer</p>
          <div class="mt-3 flex items-center justify-between gap-4">
            <div>
              <p class="type-mono-stat" style="font-size: 32px; line-height: 36px;">
                {@rest_timer.remaining_seconds}s
              </p>
              <p class="mt-1 type-body-sm">
                Recover, then back into {@rest_timer.exercise_name}.
              </p>
            </div>
            <button type="button" phx-click="cancel_timer" class="gb-btn gb-btn--secondary gb-btn--sm">
              Clear
            </button>
          </div>
        </div>

        <div :if={@live_session} class="gb-grid">
          <div class="gb-grid__main space-y-3">
            <section
              :for={exercise <- @live_session.workout_day.exercises}
              id={"trainer-live-exercise-panel-#{exercise.id}"}
              class={[
                "gb-card transition-all duration-200",
                active_exercise?(@live_active_exercise_id, exercise.id) &&
                  "gb-card--accent shadow-[var(--shadow-md)]"
              ]}
            >
              <button
                id={"trainer-live-exercise-toggle-#{exercise.id}"}
                type="button"
                phx-click="select_live_exercise"
                phx-value-exercise_id={exercise.id}
                aria-controls={"trainer-live-exercise-body-#{exercise.id}"}
                aria-expanded={to_string(active_exercise?(@live_active_exercise_id, exercise.id))}
                class="flex w-full items-start justify-between gap-4 text-left"
              >
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2">
                    <span class="grid h-6 w-6 flex-none place-items-center rounded-pill bg-accent-soft text-xs font-bold text-accent">
                      {exercise.position}
                    </span>
                    <p class="type-label">Exercise</p>
                    <span
                      :if={active_exercise?(@live_active_exercise_id, exercise.id)}
                      class="gb-pill gb-pill--accent"
                    >
                      Active
                    </span>
                  </div>
                  <h3 class="mt-2 type-h2">{exercise.name}</h3>
                  <p class="mt-1 type-body-sm">{exercise_target(exercise)}</p>
                  <p :if={exercise.progression_hint} class="mt-2 type-body-sm text-text-muted">
                    {exercise.progression_hint}
                  </p>
                  <p class="mt-3 type-body-sm">
                    {exercise_progress_label(@live_session.exercise_logs, exercise)}
                  </p>
                </div>
                <div class="flex flex-none items-start gap-3">
                  <div class="text-right">
                    <p class="type-label inline-flex items-center gap-1.5">
                      <.icon name="hero-forward-mini" class="h-3.5 w-3.5 text-accent" /> Next set
                    </p>
                    <p class="mt-1 type-mono-stat">
                      {next_set_number(@live_session.exercise_logs, exercise.id)}
                    </p>
                  </div>
                  <.icon
                    name={
                      if active_exercise?(@live_active_exercise_id, exercise.id),
                        do: "hero-chevron-up-mini",
                        else: "hero-chevron-down-mini"
                    }
                    class="mt-1 h-5 w-5 text-text-subtle"
                  />
                </div>
              </button>

              <div
                :if={active_exercise?(@live_active_exercise_id, exercise.id)}
                id={"trainer-live-exercise-body-#{exercise.id}"}
                class="mt-5 space-y-4 border-t border-border pt-4"
              >
                <ul
                  :if={live_logs_for_exercise(@live_session.exercise_logs, exercise.id) != []}
                  class="divide-y divide-border border-y border-border"
                >
                  <li
                    :for={log <- live_logs_for_exercise(@live_session.exercise_logs, exercise.id)}
                    class="flex items-center justify-between py-3 text-sm"
                  >
                    <div>
                      <span class="font-medium text-text">Set {log.set_number}</span>
                      <span class="ml-2 text-text-muted">{log_description(log, exercise)}</span>
                    </div>
                    <span :if={log.rpe} class="type-label">RPE {log.rpe}</span>
                  </li>
                </ul>

                <form
                  id={"trainer-set-log-form-#{exercise.id}"}
                  phx-submit="log_live_set"
                  class="space-y-3"
                >
                  <input type="hidden" name="exercise_id" value={exercise.id} />

                  <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
                    <div>
                      <label class="type-label" for={"trainer-reps-#{exercise.id}"}>Reps</label>
                      <input
                        id={"trainer-reps-#{exercise.id}"}
                        type="number"
                        min="0"
                        name="exercise_log[reps_completed]"
                        class="gb-input gb-input--stat mt-2"
                      />
                    </div>
                    <div>
                      <label class="type-label" for={"trainer-weight-#{exercise.id}"}>
                        Weight kg
                      </label>
                      <input
                        id={"trainer-weight-#{exercise.id}"}
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
                    Log set {next_set_number(@live_session.exercise_logs, exercise.id)}
                  </button>
                </form>
              </div>
            </section>
          </div>

          <aside class="gb-grid__side md:sticky md:top-6 md:self-start gb-card gb-card--accent">
            <.section_head icon="hero-trophy-mini">Live progress</.section_head>
            <p class="mt-2 type-h2">{length(@live_session.exercise_logs)} sets logged</p>
            <p class="mt-2 type-body-sm">
              Started {live_session_started_label(@live_session.started_at)}
            </p>

            <button
              id="trainer-complete-workout-button"
              type="button"
              phx-click="complete_live_workout"
              class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block mt-4"
            >
              <.icon name="hero-flag-solid" class="h-4 w-4" /> Complete workout
            </button>
          </aside>
        </div>
      </section>

      <hr class="gb-divider" />

      <section :if={@active_tab == "stats"} class="space-y-8">
        <section>
          <header class="flex items-end justify-between">
            <div>
              <p class="type-label">Weight trend</p>
              <h2 class="mt-1 type-h2">{format_weight(weight_value(@detail))}</h2>
            </div>
            <p class="type-body-sm">{weight_range_label(@weight_chart)}</p>
          </header>

          <div class="mt-4">
            <svg viewBox="0 0 320 160" class="h-44 w-full">
              <line x1="16" y1="144" x2="304" y2="144" stroke="var(--border)" stroke-width="1" />
              <polyline
                points={@weight_chart.polyline_points}
                fill="none"
                stroke="var(--accent)"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                opacity={if length(@weight_chart.points) > 1, do: "1", else: "0"}
              />
              <circle
                :for={point <- @weight_chart.points}
                cx={point.x}
                cy={point.y}
                r="3"
                fill="var(--accent)"
              />
              <text
                :for={point <- @weight_chart.points}
                x={point.x}
                y="156"
                text-anchor="middle"
                fill="var(--text-subtle)"
                class="text-[10px]"
              >
                {point.label}
              </text>
            </svg>
          </div>
        </section>

        <section>
          <p class="type-label">Profile snapshot</p>
          <.list>
            <:item title="Training frequency">{training_frequency(@detail.profile)}</:item>
            <:item title="Fitness level">{fitness_level(@detail.profile)}</:item>
            <:item title="Height">{height_label(@detail.profile)}</:item>
            <:item title="Goal weight">{goal_weight_label(@detail.profile)}</:item>
          </.list>
        </section>

        <section>
          <header>
            <p class="type-label">Recent weigh-ins</p>
            <h2 class="mt-1 type-h2">{length(@detail.weight_logs)} entries</h2>
          </header>

          <ul class="mt-4 divide-y divide-border border-y border-border">
            <li
              :for={log <- Enum.reverse(Enum.take(Enum.reverse(@detail.weight_logs), 5))}
              class="flex items-center justify-between py-3 text-sm"
            >
              <div>
                <p class="font-medium text-text">{format_weight(log.weight_kg)}</p>
                <p class="type-body-sm">{Calendar.strftime(log.logged_at, "%b %-d, %Y")}</p>
              </div>
              <p class="max-w-[18ch] text-right type-body-sm">{log.notes || "—"}</p>
            </li>
            <li :if={@detail.weight_logs == []} class="py-3 type-body-sm">
              No weight logs yet for this athlete.
            </li>
          </ul>
        </section>
      </section>

      <section :if={@active_tab == "program"} class="space-y-8">
        <section>
          <header class="flex items-start justify-between gap-4">
            <div>
              <p class="type-label">Current plan</p>
              <h2 class="mt-1 type-h2">{program_title(@detail.program)}</h2>
              <p class="mt-2 type-body-sm">{program_summary(@detail.program)}</p>
            </div>
            <span class={program_status_class(@detail.program)}>
              {program_status_label(@detail.program)}
            </span>
          </header>

          <.link
            navigate={~p"/trainer/clients/#{@detail.client.id}/regenerate"}
            class="gb-btn gb-btn--secondary gb-btn--block mt-4"
          >
            <.icon name="hero-sparkles-mini" class="h-4 w-4" />
            {if @detail.program, do: "Configure & regenerate plan", else: "Configure & generate plan"}
          </.link>
        </section>

        <section :if={@program_weeks != []} class="space-y-6">
          <header class="flex items-center justify-between gap-3">
            <div>
              <p class="type-label">Athlete view</p>
              <h2 class="mt-1 type-h2">Open a day to preview, edit, or start it</h2>
            </div>
            <p :if={@live_session} class="type-body-sm text-right">
              Active session: {live_session_title(@live_session)}
            </p>
          </header>

          <.link
            :if={@next_workout_day}
            navigate={~p"/trainer/clients/#{@detail.client.id}/days/#{@next_workout_day.id}"}
            class="block rounded-card border border-accent bg-accent-soft px-4 py-4 transition hover:shadow-[var(--shadow-md)]"
          >
            <div class="flex items-center justify-between gap-3">
              <div class="min-w-0">
                <p class="type-label inline-flex items-center gap-1.5">
                  <.icon name="hero-flag-mini" class="h-3.5 w-3.5 text-accent" /> Next up for this athlete
                </p>
                <p class="mt-1 type-h3">
                  Week {@next_workout_day.week_number} · Day {@next_workout_day.day_number} — {@next_workout_day.day_label ||
                    "Workout day"}
                </p>
                <p class="mt-1 type-body-sm">{workout_day_subtitle(@next_workout_day)}</p>
              </div>
              <.icon name="hero-arrow-right-mini" class="h-5 w-5 flex-none text-accent" />
            </div>
          </.link>

          <div :for={{week_number, week_days} <- @program_weeks} class="space-y-3">
            <header class="flex items-baseline justify-between gap-3 border-b border-border pb-2">
              <p class="type-label">Week {week_number}</p>
              <p class="type-body-sm text-text-subtle">{week_summary(week_days)}</p>
            </header>

            <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
              <.link
                :for={workout_day <- week_days}
                navigate={~p"/trainer/clients/#{@detail.client.id}/days/#{workout_day.id}"}
                class={workout_day_card_class(workout_day, @live_session)}
              >
                <div class="flex items-start justify-between gap-2">
                  <span class="type-label">Day {workout_day.day_number}</span>
                  <span
                    :if={selected_session_matches_day?(@live_session, workout_day)}
                    class="gb-pill gb-pill--accent"
                  >
                    Live
                  </span>
                  <span
                    :if={
                      not selected_session_matches_day?(@live_session, workout_day) and
                        to_string(workout_day.id) == to_string(@next_workout_day_id)
                    }
                    class="gb-pill gb-pill--accent"
                  >
                    Next up
                  </span>
                </div>
                <span class="mt-1 block type-h3">
                  {workout_day.day_label || "Workout day"}
                </span>
                <span class="mt-2 flex items-center justify-between gap-2 type-body-sm">
                  {workout_day_subtitle(workout_day)}
                  <.icon name="hero-chevron-right-mini" class="h-4 w-4 flex-none text-text-subtle" />
                </span>
              </.link>
            </div>
          </div>
        </section>

        <p :if={is_nil(@detail.program)} class="type-body-sm">
          No program is attached to this client yet. Use “Configure &amp; generate plan” above to create the first coached block.
        </p>
      </section>

      <section :if={@active_tab == "photos"} class="space-y-8">
        <section>
          <header>
            <p class="type-label">Check-ins</p>
            <h2 class="mt-1 type-h2">{length(@detail.checkin_images)} visible uploads</h2>
          </header>

          <div class="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-3">
            <figure
              :for={image <- @detail.checkin_images}
              class="overflow-hidden rounded border border-border"
            >
              <img src={image.image_url} alt="Check-in image" class="h-40 w-full object-cover" />
              <figcaption class="px-3 py-2">
                <p class="text-sm font-medium text-text">
                  {Calendar.strftime(image.logged_at || Date.utc_today(), "%b %-d, %Y")}
                </p>
                <p class="mt-1 type-body-sm">{image.notes || "Check-in photo"}</p>
              </figcaption>
            </figure>
          </div>

          <p :if={@detail.checkin_images == []} class="mt-4 type-body-sm">
            No visible check-in photos yet.
          </p>
        </section>

        <section>
          <header>
            <p class="type-label">Progress gallery</p>
            <h2 class="mt-1 type-h2">{length(@detail.progress_images)} milestone photos</h2>
          </header>

          <div class="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-3">
            <figure
              :for={image <- @detail.progress_images}
              class="overflow-hidden rounded border border-border"
            >
              <img src={image.image_url} alt="Progress image" class="h-40 w-full object-cover" />
              <figcaption class="px-3 py-2">
                <p class="text-sm font-medium text-text">
                  {Calendar.strftime(image.logged_at || Date.utc_today(), "%b %-d, %Y")}
                </p>
                <p class="mt-1 type-body-sm">{image.notes || "Progress photo"}</p>
              </figcaption>
            </figure>
          </div>

          <p :if={@detail.progress_images == []} class="mt-4 type-body-sm">
            No visible progress photos yet.
          </p>
        </section>
      </section>

      <section :if={@active_tab == "prs"}>
        <header>
          <p class="type-label">Personal records</p>
          <h2 class="mt-1 type-h2">{length(@detail.personal_records)} logged PRs</h2>
        </header>

        <ul class="mt-4 divide-y divide-border border-y border-border">
          <li :for={record <- @detail.personal_records} class="flex items-center justify-between py-3">
            <div>
              <h3 class="type-h3">{record.exercise_name}</h3>
              <p class="mt-1 type-body-sm">
                {Calendar.strftime(record.achieved_at, "%b %-d, %Y")}
              </p>
            </div>
            <div class="text-right">
              <p class="type-mono-stat">{format_weight_number(record.weight_kg)} kg</p>
              <p class="type-body-sm">{record.reps} reps</p>
            </div>
          </li>
          <li :if={@detail.personal_records == []} class="py-3 type-body-sm">
            No personal records have been logged yet.
          </li>
        </ul>
      </section>
    </div>
    """
  end

  defp assign_client_detail(socket, detail) do
    socket
    |> assign(:detail, detail)
    |> assign(:weight_chart, build_weight_chart(detail.weight_logs, detail.profile))
    |> assign_program_preview()
  end

  defp reload_client_detail(socket) do
    {:ok, detail} =
      Trainer.get_managed_client_detail(
        socket.assigns.current_user.id,
        socket.assigns.detail.client.id
      )

    assign_client_detail(socket, detail)
  end

  defp refresh_client_view(socket, preferred_live_exercise_id \\ nil) do
    socket
    |> reload_client_detail()
    |> assign_live_session(socket.assigns.detail.client.id, preferred_live_exercise_id)
  end

  defp assign_live_session(socket, client_id) do
    assign_live_session(socket, client_id, nil)
  end

  defp assign_live_session(socket, client_id, preferred_live_exercise_id) do
    live_session = Training.get_active_workout_session_with_details_for_user(client_id)

    socket
    |> assign(:live_session, live_session)
    |> maybe_track_live_session(preferred_live_exercise_id)
    |> assign_program_preview()
  end

  defp assign_program_preview(socket) do
    program_workout_days =
      socket.assigns.detail.program
      |> case do
        nil -> []
        program -> List.wrap(program.workout_days)
      end

    next_workout_day_id = Programs.next_workout_day_id_for_user(socket.assigns.detail.client.id)

    next_workout_day =
      Enum.find(program_workout_days, &(to_string(&1.id) == to_string(next_workout_day_id)))

    socket
    |> assign(:program_workout_days, program_workout_days)
    |> assign(:program_weeks, group_days_by_week(program_workout_days))
    |> assign(:next_workout_day_id, next_workout_day_id)
    |> assign(:next_workout_day, next_workout_day)
  end

  defp maybe_track_live_session(socket, preferred_live_exercise_id) do
    case socket.assigns.live_session do
      nil ->
        socket
        |> assign(:rest_timer, nil)
        |> assign(:elapsed_label, "--")
        |> assign(:live_active_exercise_id, nil)
        |> assign(:tracked_workout_session_id, nil)

      session ->
        if connected?(socket) and socket.assigns[:tracked_workout_session_id] != session.id do
          Training.subscribe_to_workout(session.id)
          Training.ensure_workout_clock(session.id, session.started_at)
        end

        active_exercise_id =
          resolve_active_exercise_id(
            session,
            preferred_live_exercise_id || socket.assigns[:live_active_exercise_id]
          )

        socket
        |> assign(:tracked_workout_session_id, session.id)
        |> assign(:live_active_exercise_id, active_exercise_id)
        |> assign(:elapsed_label, elapsed_label(session.started_at))
    end
  end

  defp normalize_tab(tab) when tab in @tabs, do: tab
  defp normalize_tab(_tab), do: "stats"

  defp live_message_form(message) do
    to_form(%{"message" => message}, as: :live_message)
  end

  defp tab_button_class(tab, active_tab) do
    base = "px-3 py-3 text-sm font-semibold transition border-b-2 -mb-px"

    if tab == active_tab do
      "#{base} border-accent text-text"
    else
      "#{base} border-transparent text-text-muted hover:text-text"
    end
  end

  defp tab_label("stats"), do: "Stats"
  defp tab_label("program"), do: "Program"
  defp tab_label("photos"), do: "Photos"
  defp tab_label("prs"), do: "PRs"

  defp display_name(email) do
    email
    |> to_string()
    |> String.split("@")
    |> List.first()
    |> String.replace(~r/[._-]+/u, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp trainer_display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp trainer_display_name(user), do: display_name(user.email)

  defp live_session_title(session) do
    session.workout_day.day_label || "Workout"
  end

  defp live_session_total_sets(session) do
    length(session.exercise_logs)
  end

  defp live_session_started_label(nil), do: "just now"
  defp live_session_started_label(started_at), do: Calendar.strftime(started_at, "%H:%M")

  defp live_logs_for_exercise(exercise_logs, exercise_id) do
    exercise_logs
    |> Enum.filter(&(&1.exercise_id == exercise_id))
    |> Enum.sort_by(&{&1.set_number, &1.inserted_at})
  end

  defp group_days_by_week(program_workout_days) do
    program_workout_days
    |> Enum.group_by(& &1.week_number)
    |> Enum.map(fn {week_number, days} ->
      {week_number, Enum.sort_by(days, & &1.day_number)}
    end)
    |> Enum.sort_by(fn {week_number, _days} -> week_number end)
  end

  defp week_summary(week_days) do
    training_days = Enum.count(week_days, &(not &1.is_rest_day))

    case training_days do
      0 -> "Recovery week"
      1 -> "1 training day"
      count -> "#{count} training days"
    end
  end

  defp workout_day_card_class(workout_day, live_session) do
    active? = selected_session_matches_day?(live_session, workout_day)

    base = "block rounded-card border px-4 py-4 transition hover:border-accent hover:shadow-[var(--shadow-md)] "

    if active? do
      base <> "border-accent bg-accent-soft shadow-[var(--shadow-md)]"
    else
      base <> "border-border bg-surface"
    end
  end

  defp selected_session_matches_day?(%{workout_day_id: workout_day_id}, workout_day),
    do: to_string(workout_day_id) == to_string(workout_day.id)

  defp selected_session_matches_day?(_live_session, _workout_day), do: false

  defp normalize_log_params(params) do
    params
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp find_exercise!(exercises, exercise_id) do
    Enum.find(exercises, &(to_string(&1.id) == to_string(exercise_id))) ||
      raise Ecto.NoResultsError, queryable: Training
  end

  defp next_set_number(exercise_logs, exercise_id) do
    exercise_logs
    |> live_logs_for_exercise(exercise_id)
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
    completed_sets = exercise_logs |> live_logs_for_exercise(exercise.id) |> length()

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

  defp elapsed_label(nil), do: "--"

  defp elapsed_label(elapsed_seconds) when is_integer(elapsed_seconds) do
    minutes = div(elapsed_seconds, 60)
    seconds = rem(elapsed_seconds, 60)
    "#{minutes}m #{String.pad_leading(Integer.to_string(seconds), 2, "0")}s"
  end

  defp elapsed_label(started_at) do
    elapsed_seconds = max(DateTime.diff(DateTime.utc_now(), started_at, :second), 1)
    elapsed_label(elapsed_seconds)
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
    completed_sets = session.exercise_logs |> live_logs_for_exercise(exercise.id) |> length()
    completed_sets >= prescribed_sets
  end

  defp choose_active_exercise_id(exercises, exercise_id) do
    Enum.find_value(exercises, fn exercise ->
      if to_string(exercise.id) == to_string(exercise_id), do: exercise.id
    end)
  end

  defp format_number(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)
  defp format_number(value), do: to_string(value)

  defp relationship_badge_class("active"), do: "gb-pill gb-pill--success"
  defp relationship_badge_class("paused"), do: "gb-pill gb-pill--warning"
  defp relationship_badge_class(_status), do: "gb-pill"

  defp goal_label(nil), do: "Pending"

  defp goal_label(profile) do
    profile.goal
    |> to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp weight_value(detail) do
    case detail.latest_weight do
      nil -> detail.profile && detail.profile.weight_kg
      latest_weight -> latest_weight.weight_kg
    end
  end

  defp format_weight(nil), do: "--"
  defp format_weight(value) when is_integer(value), do: "#{value}.0 kg"

  defp format_weight(value) when is_float(value),
    do: "#{:erlang.float_to_binary(value, decimals: 1)} kg"

  defp format_weight_number(nil), do: "--"
  defp format_weight_number(value) when is_integer(value), do: "#{value}.0"

  defp format_weight_number(value) when is_float(value),
    do: :erlang.float_to_binary(value, decimals: 1)

  defp training_frequency(nil), do: "Pending"
  defp training_frequency(profile), do: "#{profile.days_per_week || "--"} days per week"

  defp fitness_level(nil), do: "Pending"
  defp fitness_level(profile), do: profile.fitness_level |> to_string() |> String.capitalize()

  defp height_label(nil), do: "Pending"

  defp height_label(profile) when is_float(profile.height_cm),
    do: "#{:erlang.float_to_binary(profile.height_cm, decimals: 1)} cm"

  defp height_label(_profile), do: "Pending"

  defp goal_weight_label(nil), do: "Pending"
  defp goal_weight_label(profile), do: format_weight(profile.goal_weight_kg)

  defp build_weight_chart(weight_logs, profile) do
    points =
      case weight_logs do
        [] ->
          fallback_weight_point(profile)

        logs ->
          Enum.map(logs, fn log ->
            %{label: Calendar.strftime(log.logged_at, "%b %-d"), weight_kg: log.weight_kg}
          end)
      end

    weights = Enum.map(points, & &1.weight_kg)

    case weights do
      [] ->
        %{max_weight: nil, min_weight: nil, points: [], polyline_points: ""}

      _ ->
        min_weight = Enum.min(weights)
        max_weight = Enum.max(weights)
        lower_bound = min_weight - 5
        upper_bound = max_weight + 5
        x_step = chart_x_step(points)

        chart_points =
          points
          |> Enum.with_index()
          |> Enum.map(fn {%{label: label, weight_kg: weight_kg}, index} ->
            %{
              label: label,
              weight_kg: weight_kg,
              x: @chart_padding + x_step * index,
              y: scaled_weight_y(weight_kg, lower_bound, upper_bound)
            }
          end)

        %{
          max_weight: max_weight,
          min_weight: min_weight,
          points: chart_points,
          polyline_points: Enum.map_join(chart_points, " ", &"#{&1.x},#{&1.y}")
        }
    end
  end

  defp fallback_weight_point(nil), do: []

  defp fallback_weight_point(profile) do
    if profile && profile.weight_kg do
      [%{label: "Start", weight_kg: profile.weight_kg}]
    else
      []
    end
  end

  defp chart_x_step(points) when length(points) <= 1, do: 0.0
  defp chart_x_step(points), do: (@chart_width - @chart_padding * 2) / (length(points) - 1)

  defp scaled_weight_y(weight, lower_bound, upper_bound) do
    usable_height = @chart_height - @chart_padding * 2
    ratio = (weight - lower_bound) / max(upper_bound - lower_bound, 1)
    @chart_height - @chart_padding - ratio * usable_height
  end

  defp weight_range_label(%{min_weight: nil, max_weight: nil}), do: "No weight data yet"

  defp weight_range_label(chart),
    do: "#{format_weight(chart.min_weight)} to #{format_weight(chart.max_weight)}"

  defp program_title(nil), do: "No program yet"
  defp program_title(program), do: program.name || "Untitled program"

  defp program_summary(nil),
    do: "Generate a program from trainer notes to get this client moving."

  defp program_summary(program) do
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

  defp program_status_label(nil), do: "Missing"
  defp program_status_label(program), do: String.capitalize(program.status)

  defp program_status_class(nil), do: "gb-pill"

  defp program_status_class(program) do
    case program.status do
      "active" -> "gb-pill gb-pill--success"
      "paused" -> "gb-pill gb-pill--warning"
      _ -> "gb-pill"
    end
  end

  defp workout_day_subtitle(%{is_rest_day: true}), do: "Rest and recovery"

  defp workout_day_subtitle(workout_day) do
    workout_day.muscle_groups
    |> List.wrap()
    |> case do
      [] -> "#{length(workout_day.exercises)} exercises"
      groups -> Enum.map_join(groups, " • ", &titleize/1)
    end
  end

  defp titleize(value) do
    value
    |> to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
