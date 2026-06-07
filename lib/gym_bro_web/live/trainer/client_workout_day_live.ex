defmodule GymBroWeb.Trainer.ClientWorkoutDayLive do
  use GymBroWeb, :live_view

  import GymBroWeb.Trainer.ClientProgramHelpers

  alias GymBro.{Onboarding, Profiles, Trainer, Training}

  @impl true
  def mount(%{"client_id" => client_id, "day_id" => day_id}, _session, socket) do
    current_user = socket.assigns.current_user
    profile = Profiles.get_trainer_profile_by_user(current_user.id)

    cond do
      is_nil(profile) ->
        {:ok, push_navigate(socket, to: Onboarding.welcome_path(current_user)), layout: false}

      true ->
        case Trainer.get_managed_client_detail(current_user.id, client_id) do
          {:ok, detail} ->
            case find_workout_day(detail.program, day_id) do
              {:ok, _workout_day} ->
                {:ok,
                 socket
                 |> assign(:active_nav, :clients)
                 |> assign(:detail, detail)
                 |> assign(:day_id, day_id)
                 |> assign_day_view()
                 |> then(&assign(&1, :page_title, day_page_title(&1.assigns.workout_day))),
                 layout: {GymBroWeb.Layouts, :trainer_app}}

              {:error, :not_found} ->
                {:ok,
                 socket
                 |> put_flash(:error, "That workout day could not be found anymore.")
                 |> push_navigate(to: ~p"/trainer/clients/#{client_id}?tab=program"), layout: false}
            end

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "That client could not be found in your roster.")
             |> push_navigate(to: ~p"/trainer/clients"), layout: false}
        end
    end
  end

  @impl true
  def handle_event("start_client_workout", %{"day_id" => day_id}, socket) do
    trainer_id = socket.assigns.current_user.id
    client_id = socket.assigns.detail.client.id

    case Trainer.get_or_start_client_workout_session(trainer_id, client_id, day_id) do
      {:ok, _session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workout session ready for this athlete.")
         |> push_navigate(to: ~p"/trainer/clients/#{client_id}?tab=program")}

      {:error, {:active_session_exists, _session}} ->
        {:noreply,
         socket
         |> put_flash(:info, "This athlete already has an active workout.")
         |> push_navigate(to: ~p"/trainer/clients/#{client_id}?tab=program")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "This client is not currently editable.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> reload_detail()
         |> put_flash(:error, "That workout day could not be found anymore.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "We could not start this workout yet.")}
    end
  end

  def handle_event("remove_exercise", %{"exercise_id" => exercise_id}, socket) do
    current_user = socket.assigns.current_user
    client_id = socket.assigns.detail.client.id

    case Trainer.remove_client_exercise(current_user.id, client_id, exercise_id) do
      :ok ->
        {:noreply,
         socket
         |> reload_detail()
         |> put_flash(:info, "Exercise removed from the day.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "This client is not currently editable.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> reload_detail()
         |> put_flash(:error, "That exercise could not be found anymore.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <.back navigate={~p"/trainer/clients/#{@detail.client.id}?tab=program"}>
          {display_name(@detail.client.email)}'s plan
        </.back>
        <span class={program_status_class(@detail.program)}>
          {program_status_label(@detail.program)}
        </span>
      </div>

      <header>
        <p class="type-label inline-flex items-center gap-1.5">
          <.icon name="hero-calendar-mini" class="h-3.5 w-3.5 text-accent" />
          Week {@workout_day.week_number} · Day {@workout_day.day_number}
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
          {trainer_status_label(@workout_day, @live_session, @completed_session)}
        </:item>
      </.stat_row>

      <section :if={not @workout_day.is_rest_day} class="gb-card gb-card--accent">
        <.section_head icon="hero-bolt-mini">Session control</.section_head>
        <h3 class="mt-2 type-h2">
          {trainer_session_cta_heading(@live_session, @workout_day)}
        </h3>
        <p class="mt-2 type-body-sm">
          {trainer_session_cta_copy(@live_session, @workout_day)}
        </p>

        <button
          id="trainer-start-workout-button"
          type="button"
          phx-click="start_client_workout"
          phx-value-day_id={@workout_day.id}
          class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block mt-4"
        >
          <.icon name="hero-play-solid" class="h-4 w-4" />
          {trainer_session_cta_label(@live_session, @workout_day)}
        </button>
      </section>

      <section :if={@completed_session} class="space-y-1">
        <.section_head icon="hero-check-circle-mini">Last completion</.section_head>
        <div class="mt-2 flex items-end justify-between gap-4">
          <div>
            <p class="type-h2">{format_datetime(@completed_session.completed_at)}</p>
            <p class="mt-1 type-body-sm">
              Finished in {format_duration(@completed_session.duration_seconds)}
            </p>
          </div>
          <p class="max-w-[18ch] text-right type-body-sm">
            {@completed_session.notes || "Ready whenever you want to repeat it."}
          </p>
        </div>
      </section>

      <.callout :if={@workout_day.trainer_notes} label="Trainer notes">
        {@workout_day.trainer_notes}
      </.callout>

      <hr class="gb-divider" />

      <section>
        <header class="flex items-center justify-between gap-3">
          <div>
            <.section_head icon="hero-fire-mini">Exercise plan</.section_head>
            <h3 class="mt-2 type-h2">
              {if @workout_day.is_rest_day,
                do: "Recovery focus",
                else: "Move through the full list"}
            </h3>
          </div>
          <.link
            :if={not @workout_day.is_rest_day}
            navigate={
              ~p"/trainer/clients/#{@detail.client.id}/days/#{@workout_day.id}/exercises/new"
            }
            class="gb-btn gb-btn--secondary gb-btn--sm"
          >
            Add exercise
          </.link>
        </header>

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
                  <h4 class="type-h3">{exercise.name}</h4>
                  <span
                    :if={Map.has_key?(@detail.overrides_by_exercise_id, exercise.id)}
                    class="gb-pill gb-pill--warning"
                  >
                    Override saved
                  </span>
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
                <p
                  :if={Map.has_key?(@detail.overrides_by_exercise_id, exercise.id)}
                  class="mt-2 type-body-sm"
                >
                  {override_summary(@detail.overrides_by_exercise_id[exercise.id])}
                </p>
                <div class="mt-3 flex flex-wrap gap-2">
                  <.link
                    navigate={
                      ~p"/trainer/clients/#{@detail.client.id}/days/#{@workout_day.id}/exercises/#{exercise.id}/edit"
                    }
                    class="gb-btn gb-btn--secondary gb-btn--sm"
                  >
                    Edit
                  </.link>
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
              <div class="text-right">
                <p class="type-label inline-flex items-center gap-1.5">
                  <.icon name="hero-pause-circle-mini" class="h-3.5 w-3.5 text-accent" /> Rest
                </p>
                <p class="mt-1 type-mono-stat">{exercise_rest_label(exercise)}</p>
              </div>
            </div>
          </li>

          <li :if={@workout_day.exercises == []} class="py-4 type-body-sm">
            No exercises are attached to this day yet.
          </li>
        </ol>
      </section>

    </div>
    """
  end

  defp assign_day_view(socket) do
    {:ok, workout_day} = find_workout_day(socket.assigns.detail.program, socket.assigns.day_id)
    client_id = socket.assigns.detail.client.id

    workout_day =
      Training.apply_progression_recommendations_to_workout_day(client_id, workout_day)

    socket
    |> assign(:workout_day, workout_day)
    |> assign(:live_session, Training.get_active_workout_session_with_details_for_user(client_id))
    |> assign(
      :completed_session,
      Training.latest_completed_workout_session_for_day(client_id, workout_day.id)
    )
  end

  defp reload_detail(socket) do
    {:ok, detail} =
      Trainer.get_managed_client_detail(
        socket.assigns.current_user.id,
        socket.assigns.detail.client.id
      )

    socket
    |> assign(:detail, detail)
    |> assign_day_view()
  end

  defp find_workout_day(nil, _day_id), do: {:error, :not_found}

  defp find_workout_day(program, day_id) do
    case Enum.find(program.workout_days, &(to_string(&1.id) == to_string(day_id))) do
      nil -> {:error, :not_found}
      workout_day -> {:ok, workout_day}
    end
  end

  defp day_page_title(workout_day) do
    "Week #{workout_day.week_number} · Day #{workout_day.day_number}"
  end
end
