defmodule GymBroWeb.Trainer.AnalyticsLive do
  use GymBroWeb, :live_view

  alias GymBro.{Analytics, Onboarding, Profiles}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = Profiles.get_trainer_profile_by_user(current_user.id)

    if is_nil(profile) do
      {:ok, push_navigate(socket, to: Onboarding.welcome_path(current_user)), layout: false}
    else
      {:ok,
       socket
       |> assign(:analytics, Analytics.trainer_overview(current_user.id))
       |> assign(:active_nav, :analytics)
       |> assign(:page_title, "Trainer analytics")
       |> assign(:profile, profile), layout: {GymBroWeb.Layouts, :trainer_app}}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <header>
        <p class="type-label">Trainer analytics</p>
        <h1 class="mt-2 type-h1">See the whole roster move.</h1>
        <p class="mt-3 max-w-[60ch] type-body text-text-muted">
          Total sessions, weekly consistency, and bodyweight momentum across your coaching roster.
        </p>
      </header>

      <.stat_row>
        <:item label="Sessions">{@analytics.summary.total_client_sessions}</:item>
        <:item label="Completed">{@analytics.summary.completed_client_sessions}</:item>
        <:item label="Avg consistency">{@analytics.avg_consistency.percent}%</:item>
      </.stat_row>

      <p class="type-body-sm">
        {@analytics.avg_consistency.client_count} active clients · {@analytics.week_range_label}
      </p>

      <hr class="gb-divider" />

      <section>
        <p class="type-label">Weight momentum</p>
        <p class="mt-2 type-h1">
          {format_weight_delta(@analytics.aggregate.total_weight_lost_kg)} lost
        </p>
        <p class="mt-1 type-body-sm">
          {@analytics.aggregate.clients_losing_weight_count} clients trending down · {format_weight_delta(
            @analytics.aggregate.average_weight_lost_kg
          )} avg loss
        </p>
      </section>

      <hr class="gb-divider" />

      <section>
        <header>
          <p class="type-label">Weight loss leaders</p>
          <h2 class="mt-1 type-h2">Who is building momentum</h2>
        </header>

        <ul class="mt-4 divide-y divide-border border-y border-border">
          <li
            :for={client <- @analytics.weight_loss_leaders}
            class="flex items-start justify-between gap-4 py-3"
          >
            <div>
              <p class="type-h3">{client.client_name}</p>
              <p class="mt-1 type-body-sm">
                {format_weight(client.start_weight_kg)} start · {format_weight(client.current_weight_kg)} current
              </p>
            </div>
            <div class="text-right">
              <p class="type-mono-stat">{format_weight_delta(client.weight_lost_kg)}</p>
              <p class="mt-1 type-label">{client.consistency_percent}% consistency</p>
            </div>
          </li>
          <li :if={@analytics.weight_loss_leaders == []} class="py-3 type-body-sm">
            No weight-loss movement is ranked yet. Once clients log more than one weigh-in, leaderboard shifts will show up here.
          </li>
        </ul>
      </section>

      <hr class="gb-divider" />

      <section>
        <header>
          <p class="type-label">Weekly snapshot</p>
          <h2 class="mt-1 type-h2">Aggregate stats</h2>
        </header>

        <.stat_row class="mt-4">
          <:item label="Completed this week">
            {@analytics.aggregate.weekly_completed_sessions}
          </:item>
          <:item label="Clients with weight data">
            {@analytics.aggregate.clients_with_weight_data_count}
          </:item>
        </.stat_row>
      </section>
    </div>
    """
  end

  defp format_weight(value) when is_float(value),
    do: "#{:erlang.float_to_binary(value, decimals: 1)} kg"

  defp format_weight(value) when is_integer(value), do: "#{value}.0 kg"
  defp format_weight(_value), do: "--"

  defp format_weight_delta(value) when is_float(value),
    do: "#{:erlang.float_to_binary(value, decimals: 1)} kg"

  defp format_weight_delta(value) when is_integer(value), do: "#{value}.0 kg"
  defp format_weight_delta(_value), do: "0.0 kg"
end
