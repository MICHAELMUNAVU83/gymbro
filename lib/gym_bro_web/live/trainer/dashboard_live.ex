defmodule GymBroWeb.Trainer.DashboardLive do
  use GymBroWeb, :live_view

  alias GymBro.Onboarding
  alias GymBro.Profiles
  alias GymBro.TrainerDashboard
  alias GymBro.Training

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = Profiles.get_trainer_profile_by_user(current_user.id)

    if is_nil(profile) do
      {:ok, push_navigate(socket, to: Onboarding.welcome_path(current_user)), layout: false}
    else
      dashboard = TrainerDashboard.home(current_user.id)

      if connected?(socket) do
        subscribe_to_client_sessions(dashboard.clients)
      end

      {:ok,
       socket
       |> assign(:profile, profile)
       |> assign(:active_nav, :dashboard)
       |> assign(:dashboard, dashboard)
       |> assign(:summary, dashboard.summary), layout: {GymBroWeb.Layouts, :trainer_app}}
    end
  end

  @impl true
  def handle_info({:client_session_event, _event, _payload}, socket) do
    {:noreply, assign_dashboard(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="gb-grid">
      <div class="gb-grid__main space-y-8">
        <header class="flex items-start justify-between gap-4">
          <div>
            <p class="type-label inline-flex items-center gap-2">
              <span class="gb-label-dot" />Trainer
            </p>
            <h1 class="mt-2 type-h1 gb-heading-accent">{display_name(@current_user.email)}</h1>
            <p class="mt-3 type-body-sm">
              {format_specialization(@profile.specialization)} coach · {@profile.years_experience || 0} yrs experience
            </p>
          </div>
          <div class="hidden gap-2 md:flex">
            <.link href={~p"/users/settings"} class="gb-btn gb-btn--secondary gb-btn--sm">
              <.icon name="hero-cog-6-tooth-mini" class="h-4 w-4" /> Settings
            </.link>
            <.link href={~p"/users/log_out"} method="delete" class="gb-btn gb-btn--ghost gb-btn--sm">
              Log out
            </.link>
          </div>
        </header>

        <.stat_row>
          <:item label="Clients" icon="hero-users-mini">{@summary.total_clients}</:item>
          <:item label="Active" icon="hero-bolt-mini">{@summary.active_clients}</:item>
          <:item label="Pending" icon="hero-envelope-mini">{@summary.pending_invitations}</:item>
        </.stat_row>

        <hr class="gb-divider" />

        <section>
          <header class="flex items-end justify-between">
            <div>
              <.section_head icon="hero-user-group-mini">Client roster</.section_head>
              <h2 class="mt-2 type-h2">Keep eyes on every athlete</h2>
            </div>
            <.link href={~p"/trainer/clients"} class="gb-btn gb-btn--secondary gb-btn--sm">
              All clients
            </.link>
          </header>

          <div class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
            <.link
              :for={client <- @dashboard.clients}
              href={~p"/trainer/clients/#{client.id}"}
              class="gb-card block transition hover:border-border-strong"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="flex min-w-0 items-center gap-3">
                  <div class="grid h-10 w-10 flex-none place-items-center rounded-pill bg-surface-alt text-sm font-semibold text-text">
                    {client.initials}
                  </div>
                  <div class="min-w-0">
                    <p class="truncate type-h3">{client.display_name}</p>
                    <p class="type-body-sm">{client.status}</p>
                  </div>
                </div>
                <span :if={client.live?} class="inline-flex items-center gap-1.5 text-xs font-semibold">
                  <span class="gb-live-dot" /> Live
                </span>
              </div>
              <p class="mt-4 type-body-sm">{client.last_session_label}</p>
              <div class="mt-3 flex items-center justify-between type-body-sm">
                <span>{client.training_frequency_label}</span>
                <span>{client.goal_label}</span>
              </div>
            </.link>

            <div
              :if={@dashboard.clients == []}
              class="col-span-full type-body-sm"
            >
              Your roster is empty for now. Client invitations land here once athletes start joining your coaching space.
            </div>
          </div>
        </section>

        <hr class="gb-divider" />

        <section>
          <header>
            <.section_head icon="hero-bolt-mini">Today's activity</.section_head>
            <h2 class="mt-2 type-h2">What moved today</h2>
          </header>

          <ul class="mt-4 divide-y divide-border border-y border-border">
            <li :for={item <- @dashboard.activity_feed} class="flex items-start gap-4 py-3">
              <span class="gb-pill flex-none">{item.badge}</span>
              <div class="min-w-0 flex-1">
                <p class="text-sm font-medium text-text">{item.title}</p>
                <p class="mt-1 type-body-sm">{item.detail}</p>
              </div>
              <p class="flex-none type-body-sm">{time_ago_label(item.sort_at)}</p>
            </li>
            <li :if={@dashboard.activity_feed == []} class="py-3 type-body-sm">
              No activity has landed yet today. Live workouts, weigh-ins, and check-ins will stream in here.
            </li>
          </ul>
        </section>

        <hr class="gb-divider" />

        <section>
          <header>
            <.section_head icon="hero-exclamation-triangle-mini">Attention alerts</.section_head>
            <h2 class="mt-2 type-h2">Follow-up queue</h2>
          </header>

          <ul class="mt-4 divide-y divide-border border-y border-border">
            <li :for={alert <- @dashboard.alerts} class="flex items-start justify-between gap-4 py-3">
              <div>
                <p class="text-sm font-medium text-text">{alert.client_name} · {alert.title}</p>
                <p class="mt-1 type-body-sm">{alert.detail}</p>
              </div>
              <span class={alert_badge_class(alert.level)}>{alert_label(alert.level)}</span>
            </li>
            <li :if={@dashboard.alerts == []} class="py-3 type-body-sm">
              Nothing needs attention right now. Your active clients are checking in and keeping sessions moving.
            </li>
          </ul>
        </section>
      </div>

      <aside class="gb-grid__side md:sticky md:top-6 md:self-start gb-card gb-card--accent">
        <.section_head icon="hero-signal-mini">Live now</.section_head>
        <p class="mt-2 type-h1" style="color: var(--accent);">{@dashboard.live_session_count}</p>
        <p class="mt-1 type-body-sm">active workout sessions</p>

        <.link href={~p"/trainer/clients/invite"} class="gb-btn gb-btn--primary gb-btn--block mt-6">
          <.icon name="hero-user-plus-mini" class="h-4 w-4" /> Invite athlete
        </.link>
        <.link href={~p"/trainer/analytics"} class="gb-btn gb-btn--secondary gb-btn--block mt-2">
          <.icon name="hero-chart-pie-mini" class="h-4 w-4" /> Analytics
        </.link>
      </aside>
    </div>
    """
  end

  defp assign_dashboard(socket) do
    dashboard = TrainerDashboard.home(socket.assigns.current_user.id)

    socket
    |> assign(:dashboard, dashboard)
    |> assign(:summary, dashboard.summary)
  end

  defp subscribe_to_client_sessions(clients) do
    Enum.each(clients, fn client ->
      Training.subscribe_to_client_session(client.id)
    end)
  end

  defp display_name(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.replace(~r/[^a-zA-Z0-9]+/, " ")
    |> String.trim()
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_specialization(nil), do: "General"
  defp format_specialization("fat_loss"), do: "Fat loss"
  defp format_specialization("general"), do: "General"
  defp format_specialization("rehab"), do: "Rehab"
  defp format_specialization("strength"), do: "Strength"
  defp format_specialization(value), do: to_string(value)

  defp time_ago_label(datetime) do
    minutes = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      minutes <= 0 -> "just now"
      minutes < 60 -> "#{minutes}m ago"
      minutes < 1_440 -> "#{div(minutes, 60)}h ago"
      true -> "#{div(minutes, 1_440)}d ago"
    end
  end

  defp alert_badge_class(:high), do: "gb-pill gb-pill--accent"
  defp alert_badge_class(:medium), do: "gb-pill gb-pill--warning"
  defp alert_badge_class(_level), do: "gb-pill"

  defp alert_label(:high), do: "Needs follow-up"
  defp alert_label(:medium), do: "Monitor"
  defp alert_label(_level), do: "Info"
end
