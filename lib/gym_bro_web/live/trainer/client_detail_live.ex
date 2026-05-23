defmodule GymBroWeb.Trainer.ClientDetailLive do
  use GymBroWeb, :live_view

  alias GymBro.Programs
  alias GymBro.Programs.Exercise
  alias GymBro.{Onboarding, Profiles, Trainer, Training}

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
             |> assign(:regenerating, false)
             |> assign(:exercise_editor, nil)
             |> assign(:exercise_form, nil)
             |> assign(:live_message_form, live_message_form(""))
             |> assign_client_detail(detail)
             |> assign(
               :regeneration_form,
               regeneration_form("", regeneration_block_weeks(detail))
             )
             |> assign_live_session(detail.client.id),
             layout: {GymBroWeb.Layouts, :trainer_app}}

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

  def handle_event("show_add_exercise", %{"day_id" => day_id}, socket) do
    with {:ok, workout_day} <- find_workout_day(socket.assigns.detail.program, day_id) do
      exercise = %Exercise{
        workout_day_id: workout_day.id,
        position: Programs.next_exercise_position(workout_day.id)
      }

      {:noreply,
       socket
       |> assign(:active_tab, "program")
       |> assign(:exercise_editor, %{
         mode: :new,
         workout_day_id: workout_day.id,
         exercise: exercise
       })
       |> assign(:exercise_form, to_form(Programs.change_exercise(exercise)))}
    else
      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That workout day is no longer available.")}
    end
  end

  def handle_event("show_edit_exercise", %{"exercise_id" => exercise_id}, socket) do
    with {:ok, exercise} <- find_exercise(socket.assigns.detail.program, exercise_id) do
      {:noreply,
       socket
       |> assign(:active_tab, "program")
       |> assign(:exercise_editor, %{
         mode: :edit,
         workout_day_id: exercise.workout_day_id,
         exercise: exercise
       })
       |> assign(:exercise_form, to_form(Programs.change_exercise(exercise)))}
    else
      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That exercise is no longer available.")}
    end
  end

  def handle_event("cancel_exercise", _params, socket) do
    {:noreply, clear_exercise_editor(socket)}
  end

  def handle_event("validate_exercise", %{"exercise" => params}, socket) do
    editor = socket.assigns.exercise_editor
    exercise = editor.exercise

    changeset =
      exercise
      |> Programs.change_exercise(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :exercise_form, to_form(changeset))}
  end

  def handle_event("save_exercise", %{"exercise" => params}, socket) do
    editor = socket.assigns.exercise_editor
    current_user = socket.assigns.current_user
    client_id = socket.assigns.detail.client.id

    result =
      case editor.mode do
        :new ->
          Trainer.add_exercise_to_client_day(
            current_user.id,
            client_id,
            editor.workout_day_id,
            params
          )

        :edit ->
          Trainer.update_client_exercise(current_user.id, client_id, editor.exercise.id, params)
      end

    case result do
      {:ok, _exercise} ->
        {:noreply,
         socket
         |> reload_client_detail()
         |> clear_exercise_editor()
         |> assign(:active_tab, "program")
         |> put_flash(:info, success_message(editor.mode))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :exercise_form, to_form(changeset))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "This client is not currently editable.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> reload_client_detail()
         |> clear_exercise_editor()
         |> put_flash(:error, "That exercise could not be found anymore.")}
    end
  end

  def handle_event("remove_exercise", %{"exercise_id" => exercise_id}, socket) do
    current_user = socket.assigns.current_user
    client_id = socket.assigns.detail.client.id

    case Trainer.remove_client_exercise(current_user.id, client_id, exercise_id) do
      :ok ->
        {:noreply,
         socket
         |> reload_client_detail()
         |> clear_exercise_editor_if_matching(exercise_id)
         |> assign(:active_tab, "program")
         |> put_flash(:info, "Exercise removed from the day.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "This client is not currently editable.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> reload_client_detail()
         |> clear_exercise_editor_if_matching(exercise_id)
         |> put_flash(:error, "That exercise could not be found anymore.")}
    end
  end

  def handle_event(
        "regenerate_plan",
        %{"regeneration" => %{"block_weeks" => block_weeks, "trainer_notes" => trainer_notes}},
        socket
      ) do
    trainer_notes = trainer_notes || ""
    block_weeks = parse_block_weeks(block_weeks)
    trainer_id = socket.assigns.current_user.id
    client_id = socket.assigns.detail.client.id

    {:noreply,
     socket
     |> assign(:active_tab, "program")
     |> assign(:regenerating, true)
     |> assign(:regeneration_form, regeneration_form(trainer_notes, block_weeks))
     |> start_async(:regenerate_program, fn ->
       Trainer.regenerate_client_program(
         trainer_id,
         client_id,
         trainer_notes,
         %{block_weeks: block_weeks}
       )
     end)}
  end

  @impl true
  def handle_async(:regenerate_program, {:ok, {:ok, _program}}, socket) do
    {:noreply,
     socket
     |> reload_client_detail()
     |> assign(:regenerating, false)
     |> assign(:active_tab, "program")
     |> put_flash(:info, "Fresh AI program generated for this client.")}
  end

  def handle_async(:regenerate_program, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:regenerating, false)
     |> put_flash(:error, regeneration_error(reason))}
  end

  def handle_async(:regenerate_program, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:regenerating, false)
     |> put_flash(:error, "Plan regeneration stopped unexpectedly. Please try again.")}
  end

  @impl true
  def handle_info({:client_session_event, _event, _payload}, socket) do
    {:noreply, assign_live_session(socket, socket.assigns.detail.client.id)}
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

      <section>
        <header class="flex items-start justify-between gap-4">
          <div>
            <p class="type-label inline-flex items-center gap-2">
              <span :if={@live_session} class="gb-live-dot" /> Live session
            </p>
            <h2 class="mt-2 type-h2">
              {if @live_session,
                do: live_session_title(@live_session),
                else: "Waiting for a check-in"}
            </h2>
            <p class="mt-2 type-body-sm">
              {if @live_session,
                do: "Read-only live view of sets landing in real time.",
                else:
                  "As soon as this athlete starts a workout, their session and logged sets will appear here."}
            </p>
          </div>
          <div :if={@live_session} class="text-right">
            <p class="type-label">Sets logged</p>
            <p class="mt-1 type-mono-stat">{live_session_total_sets(@live_session)}</p>
            <p class="mt-1 type-body-sm">
              since {live_session_started_label(@live_session.started_at)}
            </p>
          </div>
        </header>

        <.form
          id="live-message-form"
          for={@live_message_form}
          phx-submit="send_live_message"
          class="mt-4 space-y-3"
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

        <div :if={@live_session} class="mt-6 space-y-6">
          <article :for={exercise <- @live_session.workout_day.exercises}>
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="type-label">Exercise {exercise.position}</p>
                <h3 class="mt-1 type-h3">{exercise.name}</h3>
                <p class="mt-1 type-body-sm">{exercise_summary(exercise)}</p>
              </div>
              <div class="text-right">
                <p class="type-label">Logged</p>
                <p class="mt-1 type-mono-stat">
                  {length(live_logs_for_exercise(@live_session.exercise_logs, exercise.id))}
                </p>
              </div>
            </div>

            <ul
              :if={live_logs_for_exercise(@live_session.exercise_logs, exercise.id) != []}
              class="mt-3 divide-y divide-border border-y border-border"
            >
              <li
                :for={log <- live_logs_for_exercise(@live_session.exercise_logs, exercise.id)}
                class="flex items-center justify-between py-2 text-sm"
              >
                <div>
                  <span class="font-medium text-text">Set {log.set_number}</span>
                  <span class="ml-2 text-text-muted">{live_log_description(log)}</span>
                </div>
                <span :if={log.rpe} class="type-label">RPE {log.rpe}</span>
              </li>
            </ul>

            <p
              :if={live_logs_for_exercise(@live_session.exercise_logs, exercise.id) == []}
              class="mt-3 type-body-sm"
            >
              No sets logged for this movement yet.
            </p>
          </article>
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
        </section>

        <.callout label="AI refresh">
          <h2 class="type-h3">Regenerate around your notes</h2>
          <p class="mt-1 type-body-sm">
            Add context about movement limits, intensity, schedule changes, or focus areas and generate a fresh coached version of the program.
          </p>

          <.form
            id="regeneration-form"
            for={@regeneration_form}
            phx-submit="regenerate_plan"
            class="mt-4 space-y-3"
          >
            <.input
              field={@regeneration_form[:block_weeks]}
              type="select"
              label="Block length"
              options={block_weeks_options()}
            />
            <.input
              field={@regeneration_form[:trainer_notes]}
              type="textarea"
              label="Trainer notes for AI"
              placeholder="Example: Reduce axial loading, keep sessions under 50 minutes, bias glute work, and leave one lower day as machine dominant."
            />
            <button
              type="submit"
              class="gb-btn gb-btn--primary gb-btn--block"
              disabled={@regenerating}
            >
              {if @regenerating, do: "Regenerating plan…", else: "Regenerate program"}
            </button>
          </.form>
        </.callout>

        <section :if={@exercise_form} class="gb-card">
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="type-label">Exercise editor</p>
              <h2 class="mt-1 type-h2">{exercise_form_title(@exercise_editor)}</h2>
            </div>
            <button type="button" phx-click="cancel_exercise" class="gb-btn gb-btn--ghost gb-btn--sm">
              Close
            </button>
          </div>

          <.form
            id="trainer-exercise-form"
            for={@exercise_form}
            phx-change="validate_exercise"
            phx-submit="save_exercise"
            class="mt-4 space-y-3"
          >
            <.input field={@exercise_form[:name]} type="text" label="Exercise name" />
            <div class="grid grid-cols-2 gap-3">
              <.input field={@exercise_form[:sets]} type="number" label="Sets" stat />
              <.input field={@exercise_form[:reps]} type="text" label="Reps" placeholder="8-10" />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <.input field={@exercise_form[:rest_seconds]} type="number" label="Rest seconds" stat />
              <.input
                field={@exercise_form[:weight_kg]}
                type="number"
                step="0.1"
                label="Weight kg"
                stat
              />
            </div>
            <.input field={@exercise_form[:notes]} type="textarea" label="Exercise notes" />
            <.input field={@exercise_form[:visual_guide]} type="textarea" label="Visual guide" />
            <.input field={@exercise_form[:trainer_notes]} type="textarea" label="Trainer notes" />
            <.input field={@exercise_form[:is_timed]} type="checkbox" label="Timed exercise" />
            <.input
              field={@exercise_form[:duration_seconds]}
              type="number"
              label="Duration seconds"
              stat
            />

            <button type="submit" class="gb-btn gb-btn--primary gb-btn--block">
              {exercise_submit_label(@exercise_editor)}
            </button>
          </.form>
        </section>

        <p :if={is_nil(@detail.program)} class="type-body-sm">
          No program is attached to this client yet. Use the AI regenerate form above to create the first coached block.
        </p>

        <section
          :for={workout_day <- List.wrap(@detail.program && @detail.program.workout_days)}
          class="space-y-3"
        >
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="type-label">
                Week {workout_day.week_number} · Day {workout_day.day_number}
              </p>
              <h2 class="mt-1 type-h2">{workout_day.day_label || "Workout day"}</h2>
              <p class="mt-1 type-body-sm">{workout_day_subtitle(workout_day)}</p>
            </div>

            <button
              :if={not workout_day.is_rest_day}
              type="button"
              phx-click="show_add_exercise"
              phx-value-day_id={workout_day.id}
              class="gb-btn gb-btn--secondary gb-btn--sm"
            >
              Add exercise
            </button>
          </div>

          <p :if={workout_day.trainer_notes} class="type-body-sm" style="color: var(--accent)">
            Trainer: {workout_day.trainer_notes}
          </p>

          <p :if={workout_day.is_rest_day} class="type-body-sm">
            Rest day programmed for recovery and reset.
          </p>

          <ol :if={not workout_day.is_rest_day} class="divide-y divide-border border-y border-border">
            <li :for={exercise <- workout_day.exercises} class="py-4">
              <div class="flex items-start justify-between gap-4">
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <span class="type-label">Exercise {exercise.position}</span>
                    <span
                      :if={Map.has_key?(@detail.overrides_by_exercise_id, exercise.id)}
                      class="gb-pill gb-pill--warning"
                    >
                      Override saved
                    </span>
                  </div>
                  <h3 class="mt-1 type-h3">{exercise.name}</h3>
                  <p class="mt-1 type-body-sm">{exercise_summary(exercise)}</p>
                  <p :if={exercise.notes} class="mt-2 type-body-sm">{exercise.notes}</p>
                  <p :if={exercise.visual_guide} class="mt-2 type-body-sm">
                    Visual guide: {exercise.visual_guide}
                  </p>
                  <p
                    :if={exercise.trainer_notes}
                    class="mt-2 type-body-sm"
                    style="color: var(--accent)"
                  >
                    Trainer: {exercise.trainer_notes}
                  </p>
                  <p
                    :if={Map.has_key?(@detail.overrides_by_exercise_id, exercise.id)}
                    class="mt-2 type-body-sm"
                  >
                    {override_summary(@detail.overrides_by_exercise_id[exercise.id])}
                  </p>
                </div>

                <div class="flex flex-col gap-2">
                  <button
                    type="button"
                    phx-click="show_edit_exercise"
                    phx-value-exercise_id={exercise.id}
                    class="gb-btn gb-btn--secondary gb-btn--sm"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    phx-click="remove_exercise"
                    phx-value-exercise_id={exercise.id}
                    data-confirm="Remove this exercise from the day?"
                    class="gb-btn gb-btn--destructive gb-btn--sm"
                  >
                    Remove
                  </button>
                </div>
              </div>
            </li>

            <li :if={workout_day.exercises == []} class="py-4 type-body-sm">
              No exercises are attached to this day yet.
            </li>
          </ol>
        </section>
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
  end

  defp reload_client_detail(socket) do
    {:ok, detail} =
      Trainer.get_managed_client_detail(
        socket.assigns.current_user.id,
        socket.assigns.detail.client.id
      )

    assign_client_detail(socket, detail)
  end

  defp assign_live_session(socket, client_id) do
    assign(
      socket,
      :live_session,
      Training.get_active_workout_session_with_details_for_user(client_id)
    )
  end

  defp clear_exercise_editor(socket) do
    socket
    |> assign(:exercise_editor, nil)
    |> assign(:exercise_form, nil)
  end

  defp clear_exercise_editor_if_matching(socket, exercise_id) do
    editor = socket.assigns.exercise_editor

    if editor && editor.mode == :edit && to_string(editor.exercise.id) == to_string(exercise_id) do
      clear_exercise_editor(socket)
    else
      socket
    end
  end

  defp find_workout_day(nil, _day_id), do: {:error, :not_found}

  defp find_workout_day(program, day_id) do
    case Enum.find(program.workout_days, &(to_string(&1.id) == to_string(day_id))) do
      nil -> {:error, :not_found}
      workout_day -> {:ok, workout_day}
    end
  end

  defp find_exercise(nil, _exercise_id), do: {:error, :not_found}

  defp find_exercise(program, exercise_id) do
    program.workout_days
    |> Enum.find_value(fn workout_day ->
      Enum.find(workout_day.exercises, &(to_string(&1.id) == to_string(exercise_id)))
    end)
    |> case do
      nil -> {:error, :not_found}
      exercise -> {:ok, exercise}
    end
  end

  defp normalize_tab(tab) when tab in @tabs, do: tab
  defp normalize_tab(_tab), do: "stats"

  defp regeneration_form(trainer_notes, block_weeks) do
    to_form(%{"block_weeks" => to_string(block_weeks), "trainer_notes" => trainer_notes},
      as: :regeneration
    )
  end

  defp regeneration_block_weeks(%{program: %{total_weeks: total_weeks}})
       when is_integer(total_weeks) and total_weeks > 0,
       do: total_weeks

  defp regeneration_block_weeks(%{profile: %{preferred_block_weeks: total_weeks}})
       when is_integer(total_weeks) and total_weeks > 0,
       do: total_weeks

  defp regeneration_block_weeks(_detail), do: 9

  defp parse_block_weeks(value) when is_integer(value) and value > 0, do: value

  defp parse_block_weeks(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _} when parsed > 0 -> parsed
      _ -> 9
    end
  end

  defp parse_block_weeks(_value), do: 9

  defp block_weeks_options do
    Enum.map(3..16, fn weeks -> {"#{weeks} weeks", Integer.to_string(weeks)} end)
  end

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

  defp live_log_description(log) do
    [
      if(log.reps_completed, do: "#{log.reps_completed} reps"),
      if(log.weight_kg, do: "#{format_weight_number(log.weight_kg)} kg"),
      if(log.duration_seconds, do: "#{log.duration_seconds}s"),
      if(log.is_personal_record, do: "PR")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" • ")
  end

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

  defp exercise_summary(exercise) do
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

  defp override_summary(override) do
    [
      if(override.sets, do: "#{override.sets} sets"),
      if(override.reps, do: "#{override.reps} reps"),
      if(override.weight_kg, do: "#{format_weight_number(override.weight_kg)} kg"),
      override.notes
    ]
    |> Enum.reject(fn value -> is_nil(value) or value == "" end)
    |> Enum.join(" • ")
  end

  defp titleize(value) do
    value
    |> to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp exercise_form_title(%{mode: :new}), do: "Add an exercise"
  defp exercise_form_title(%{mode: :edit}), do: "Edit exercise"
  defp exercise_form_title(_editor), do: "Exercise"

  defp exercise_submit_label(%{mode: :new}), do: "Add exercise"
  defp exercise_submit_label(%{mode: :edit}), do: "Save exercise"
  defp exercise_submit_label(_editor), do: "Save"

  defp success_message(:new), do: "Exercise added to the client day."
  defp success_message(:edit), do: "Exercise update saved."

  defp regeneration_error(:missing_profile),
    do: "This client needs a completed profile before AI can build a plan."

  defp regeneration_error(:missing_openai_api_key),
    do: "OpenAI is not configured in this environment yet."

  defp regeneration_error(:openai_timeout),
    do: "Plan generation timed out. Please try again."

  defp regeneration_error(:openai_rate_limited),
    do: "OpenAI is busy right now. Please try regenerating again in a moment."

  defp regeneration_error(_reason), do: "We could not regenerate the plan yet. Please try again."
end
