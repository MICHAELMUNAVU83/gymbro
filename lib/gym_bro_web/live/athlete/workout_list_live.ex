defmodule GymBroWeb.Athlete.WorkoutListLive do
  use GymBroWeb, :live_view

  alias GymBro.{Onboarding, Programs, Training}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case Onboarding.next_path(current_user) do
      "/" ->
        {:ok,
         socket
         |> assign_workout_data(current_user)
         |> assign(:active_nav, :workouts)
         |> assign(:page_title, "Workout Flow")}

      path ->
        {:ok, push_navigate(socket, to: path), layout: false}
    end
  end

  @impl true
  def handle_event("show_week", %{"week" => week}, socket) do
    {:noreply, assign(socket, :expanded_week_number, parse_week_number(week))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <header>
        <p class="type-label inline-flex items-center gap-2">
          <span class="gb-label-dot" />Workout flow
        </p>
        <h1 class="mt-2 type-h1 gb-heading-accent">One week open, the rest within reach.</h1>
        <p class="mt-3 max-w-[60ch] type-body text-text-muted">
          This view follows the full {@program_total_weeks}-week block. Keep the current week open, then jump ahead without flooding the page.
        </p>
      </header>

      <section :if={@active_session}>
        <.callout label="In session">
          <div class="flex items-center justify-between gap-4">
            <div>
              <p class="type-h3 inline-flex items-center gap-2">
                <.icon name="hero-bolt-solid" class="h-4 w-4 text-accent" />
                {active_session_heading(@active_session)}
              </p>
              <p class="mt-1 type-body-sm">
                Pick up where you left off without losing your rest timer or set history.
              </p>
            </div>
            <.link
              navigate={~p"/workouts/session/#{@active_session.id}"}
              class="gb-btn gb-btn--primary"
            >
              <.icon name="hero-play-solid" class="h-4 w-4" /> Resume
            </.link>
          </div>
        </.callout>
      </section>

      <section :if={@workout_weeks == []} class="type-body-sm">
        Your active program has not populated workout days yet. Once a plan is attached, your full training week will show up here.
      </section>

      <section
        :for={{week_number, workout_days} <- @workout_weeks}
        class="rounded-[28px] border border-border bg-surface shadow-sm"
      >
        <button
          type="button"
          phx-click="show_week"
          phx-value-week={week_number}
          class="flex w-full items-start justify-between gap-4 px-6 py-5 text-left"
          aria-expanded={to_string(week_number == @expanded_week_number)}
        >
          <div>
            <.section_head icon="hero-fire-mini">Training block</.section_head>
            <div class="mt-2 flex items-center gap-3">
              <h2 class="type-h2">Week {week_number}</h2>
              <span :if={week_number == @current_week} class="gb-pill gb-pill--accent">Current</span>
            </div>
            <p class="mt-2 type-body-sm text-text-muted">
              {compressed_week_preview(workout_days)}
            </p>
          </div>

          <div class="text-right">
            <p class="type-body-sm inline-flex items-center gap-1.5">
              <.icon name="hero-calendar-days-mini" class="h-4 w-4 text-accent" />
              {length(workout_days)} days scheduled
            </p>
            <p class="mt-3 type-label">
              {if week_number == @expanded_week_number, do: "Open", else: "Compressed"}
            </p>
          </div>
        </button>

        <div :if={week_number == @expanded_week_number} class="px-6 pb-6">
          <hr class="gb-divider--accent" />

          <div class="grid grid-cols-1 gap-4 pt-5 md:grid-cols-2">
            <.link
              :for={workout_day <- workout_days}
              navigate={~p"/workouts/#{workout_day.id}"}
              class={[
                "gb-card block transition hover:border-border-strong hover:shadow-md",
                day_accent_class(workout_day, @completed_day_ids, @active_session)
              ]}
            >
              <div class="flex items-start justify-between gap-4">
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <.icon
                      name={day_icon(workout_day)}
                      class={"h-4 w-4 #{day_icon_color(workout_day, @completed_day_ids, @active_session)}"}
                    />
                    <span class="type-label">Day {workout_day.day_number}</span>
                    <span class={status_class(workout_day, @completed_day_ids, @active_session)}>
                      {status_label(workout_day, @completed_day_ids, @active_session)}
                    </span>
                  </div>
                  <h3 class="mt-2 type-h3">{workout_day.day_label || "Workout day"}</h3>
                  <p class="mt-1 type-body-sm">{workout_day_subtitle(workout_day)}</p>
                </div>

                <div class="text-right">
                  <p class="type-label inline-flex items-center gap-1.5">
                    <.icon name="hero-clock-mini" class="h-3.5 w-3.5 text-accent" /> Duration
                  </p>
                  <p class="mt-1 type-mono-stat">
                    {format_minutes(workout_day.estimated_duration_min)}
                  </p>
                </div>
              </div>

              <hr class="gb-divider" />

              <p class="type-body-sm">
                {Enum.map_join(Enum.take(workout_day.exercises, 3), " · ", & &1.name)}
              </p>
            </.link>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp day_icon(%{is_rest_day: true}), do: "hero-moon-mini"
  defp day_icon(_workout_day), do: "hero-fire-mini"

  defp day_icon_color(%{is_rest_day: true}, _ids, _session), do: "text-text-subtle"

  defp day_icon_color(workout_day, _ids, %{workout_day_id: workout_day_id})
       when workout_day.id == workout_day_id,
       do: "text-accent"

  defp day_icon_color(workout_day, completed_day_ids, _active_session) do
    if MapSet.member?(completed_day_ids, workout_day.id),
      do: "text-success",
      else: "text-accent"
  end

  defp day_accent_class(%{is_rest_day: true}, _ids, _session), do: nil

  defp day_accent_class(workout_day, _ids, %{workout_day_id: workout_day_id})
       when workout_day.id == workout_day_id,
       do: "gb-card--accent"

  defp day_accent_class(_workout_day, _ids, _session), do: nil

  defp assign_workout_data(socket, current_user) do
    workout_days = Programs.list_workout_days_for_user(current_user.id)
    active_program = Programs.get_active_program_for_user(current_user.id)
    active_session = Training.get_active_workout_session_for_user(current_user.id)

    completed_day_ids =
      current_user.id
      |> Training.list_workout_sessions_for_user()
      |> Enum.filter(&(&1.status == "completed"))
      |> Enum.map(& &1.workout_day_id)
      |> MapSet.new()

    workout_weeks =
      workout_days
      |> Enum.group_by(& &1.week_number)
      |> Enum.sort_by(fn {week_number, _days} -> week_number end)

    expanded_week_number =
      default_expanded_week_number(
        active_program && active_program.current_week,
        workout_weeks
      )

    socket
    |> assign(:current_week, default_current_week(active_program, workout_weeks))
    |> assign(:active_session, active_session)
    |> assign(:completed_day_ids, completed_day_ids)
    |> assign(:expanded_week_number, expanded_week_number)
    |> assign(:program_total_weeks, default_program_total_weeks(active_program, workout_weeks))
    |> assign(:workout_weeks, workout_weeks)
  end

  defp default_expanded_week_number(current_week, workout_weeks) when is_integer(current_week) do
    available_weeks = Enum.map(workout_weeks, fn {week_number, _days} -> week_number end)

    if current_week in available_weeks do
      current_week
    else
      available_weeks |> List.first() |> Kernel.||(1)
    end
  end

  defp default_expanded_week_number(_current_week, workout_weeks) do
    workout_weeks
    |> List.first()
    |> case do
      {week_number, _days} -> week_number
      nil -> 1
    end
  end

  defp default_current_week(%{current_week: current_week}, _workout_weeks)
       when is_integer(current_week) and current_week > 0,
       do: current_week

  defp default_current_week(_program, workout_weeks),
    do: default_expanded_week_number(nil, workout_weeks)

  defp default_program_total_weeks(%{total_weeks: total_weeks}, _workout_weeks)
       when is_integer(total_weeks) and total_weeks > 0,
       do: total_weeks

  defp default_program_total_weeks(_program, workout_weeks), do: length(workout_weeks)

  defp active_session_heading(active_session) do
    "Day #{active_session.workout_day_id} ready to resume"
  end

  defp status_label(%{is_rest_day: true}, _completed_day_ids, _active_session), do: "Rest"

  defp status_label(workout_day, _completed_day_ids, %{workout_day_id: workout_day_id})
       when workout_day.id == workout_day_id do
    "Active"
  end

  defp status_label(workout_day, completed_day_ids, _active_session) do
    if MapSet.member?(completed_day_ids, workout_day.id), do: "Completed", else: "Ready"
  end

  defp status_class(%{is_rest_day: true}, _completed_day_ids, _active_session), do: "gb-pill"

  defp status_class(workout_day, _completed_day_ids, %{workout_day_id: workout_day_id})
       when workout_day.id == workout_day_id do
    "gb-pill gb-pill--success"
  end

  defp status_class(workout_day, completed_day_ids, _active_session) do
    if MapSet.member?(completed_day_ids, workout_day.id) do
      "gb-pill gb-pill--success"
    else
      "gb-pill"
    end
  end

  defp workout_day_subtitle(%{is_rest_day: true}) do
    "Recovery day"
  end

  defp workout_day_subtitle(workout_day) do
    workout_day.muscle_groups
    |> List.wrap()
    |> case do
      [] -> "#{length(workout_day.exercises)} exercises"
      groups -> Enum.map_join(groups, " • ", &titleize/1)
    end
  end

  defp compressed_week_preview(workout_days) do
    labels =
      workout_days
      |> Enum.take(3)
      |> Enum.map(fn workout_day -> workout_day.day_label || "Day #{workout_day.day_number}" end)

    suffix =
      case max(length(workout_days) - length(labels), 0) do
        0 -> ""
        remaining -> " +#{remaining} more"
      end

    Enum.join(labels, " · ") <> suffix
  end

  defp parse_week_number(value) when is_integer(value), do: value

  defp parse_week_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {week_number, _} when week_number > 0 -> week_number
      _ -> 1
    end
  end

  defp parse_week_number(_value), do: 1

  defp format_minutes(nil), do: "--"
  defp format_minutes(value), do: "#{value} min"

  defp titleize(value) do
    value
    |> to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
