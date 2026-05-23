defmodule GymBroWeb.Onboarding.GeneratingLive do
  use GymBroWeb, :live_view

  alias GymBro.AI.PlanGenerator
  alias GymBro.Onboarding
  alias GymBro.Programs
  alias GymBro.Profiles

  @redirect_delay_ms 150

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case access_path(current_user) do
      :ok ->
        if connected?(socket) do
          Process.send_after(self(), :finish_onboarding, @redirect_delay_ms)
        end

        profile = Profiles.get_user_profile_by_user(current_user.id)

        {:ok, assign(socket, :profile, profile), layout: false}

      path ->
        {:ok, push_navigate(socket, to: path), layout: false}
    end
  end

  @impl true
  def handle_info(:finish_onboarding, socket) do
    case finish_onboarding(socket.assigns.current_user, socket.assigns.profile) do
      {:ok, _program} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your first training plan is ready.")
         |> push_navigate(to: ~p"/")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "We couldn't generate your plan yet. Please review your goals and try again."
         )
         |> push_navigate(to: ~p"/onboarding/goals")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="app-shell py-10">
      <.flash_group flash={@flash} />

      <div class="mx-auto max-w-xl">
        <p class="type-label">Step 3 of 3</p>
        <h1 class="mt-3 type-h1">Generating your plan</h1>
        <p class="mt-3 type-body text-text-muted">
          Building your first 9-week block so your dashboard opens with a real program ready to follow.
        </p>

        <div class="mt-8 space-y-4">
          <div class="border-y border-border py-4">
            <p class="type-label">Goal</p>
            <p class="mt-1 type-h3">{pretty_value(@profile && @profile.goal)}</p>
            <p class="mt-1 type-body-sm">
              {(@profile && @profile.days_per_week) || 0} training days each week with {pretty_value(
                @profile && @profile.equipment
              )} access.
            </p>
            <p :if={@profile && @profile.preferred_session_minutes} class="mt-1 type-body-sm">
              Targeting roughly {@profile.preferred_session_minutes} minutes per training day.
            </p>
          </div>

          <div class="h-1 overflow-hidden rounded-pill bg-surface-alt">
            <div class="h-full w-3/4 animate-pulse rounded-pill" style="background: var(--accent);">
            </div>
          </div>

          <div class="grid grid-cols-3 gap-3 type-label">
            <div>Stats saved</div>
            <div>Goals mapped</div>
            <div>Plan built</div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp access_path(%{role: "athlete"} = user) do
    case Onboarding.next_path(user) do
      "/onboarding/generating" -> :ok
      path -> path
    end
  end

  defp access_path(user), do: Onboarding.next_path(user)

  defp pretty_value(nil), do: "Not set"
  defp pretty_value("weight_loss"), do: "Weight loss"
  defp pretty_value("muscle_gain"), do: "Muscle gain"
  defp pretty_value("maintenance"), do: "Maintenance"
  defp pretty_value("gym"), do: "gym"
  defp pretty_value("home"), do: "home gym"
  defp pretty_value("minimal"), do: "minimal equipment"
  defp pretty_value(value), do: to_string(value)

  defp finish_onboarding(user, profile) do
    with {:ok, _program} <- ensure_program(user, profile),
         {:ok, _profile} <- Profiles.upsert_user_profile(user.id, %{onboarding_complete: true}) do
      {:ok, :complete}
    end
  end

  defp ensure_program(user, _profile) do
    case Programs.get_active_program_for_user(user.id) do
      nil -> generate_program(user)
      program -> {:ok, program}
    end
  end

  defp generate_program(user) do
    profile = Profiles.get_user_profile_by_user(user.id)

    with %{} <- profile,
         {:ok, parsed_plan} <- PlanGenerator.generate(profile),
         {:ok, program} <-
           Programs.import_ai_plan(user.id, user.id, parsed_plan, %{status: "active"}) do
      {:ok, program}
    else
      nil -> {:error, :missing_profile}
      {:error, reason} -> {:error, reason}
    end
  end
end
