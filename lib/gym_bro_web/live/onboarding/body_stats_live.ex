defmodule GymBroWeb.Onboarding.BodyStatsLive do
  use GymBroWeb, :live_view

  alias GymBro.Onboarding
  alias GymBro.Profiles
  alias GymBro.Profiles.UserProfile

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case access_path(current_user) do
      :ok ->
        profile = Profiles.get_user_profile_by_user(current_user.id) || %UserProfile{user_id: current_user.id}

        {:ok,
         socket
         |> assign(:form, form_for(profile))
         |> assign(:current_user, current_user), layout: false}

      path ->
        {:ok, push_navigate(socket, to: path), layout: false}
    end
  end

  @impl true
  def handle_event("validate", %{"profile" => params}, socket) do
    profile = current_profile(socket)
    changeset = profile |> Profiles.change_user_profile(params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :form, to_form(changeset, as: :profile))}
  end

  def handle_event("save", %{"profile" => params}, socket) do
    case Profiles.upsert_user_profile(socket.assigns.current_user.id, params) do
      {:ok, _profile} ->
        {:noreply, push_navigate(socket, to: ~p"/onboarding/goals")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :profile))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="app-shell py-10">
      <.flash_group flash={@flash} />

      <div class="mx-auto max-w-xl">
        <p class="type-label">Step 1 of 3</p>
        <h1 class="mt-3 type-h1">Body stats</h1>
        <p class="mt-3 type-body text-text-muted">
          These numbers give us the baseline for your training profile.
        </p>

        <.form
          for={@form}
          id="body-stats-form"
          phx-change="validate"
          phx-submit="save"
          class="mt-8 space-y-5"
        >
          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <div>
              <label for="profile_age" class="type-label">Age</label>
              <input
                id="profile_age"
                name="profile[age]"
                type="number"
                value={@form[:age].value}
                min="1"
                class="gb-input gb-input--stat mt-2"
              />
              <.error :for={msg <- @form[:age].errors}>{translate_error(msg)}</.error>
            </div>

            <div>
              <label for="profile_height_cm" class="type-label">Height (cm)</label>
              <input
                id="profile_height_cm"
                name="profile[height_cm]"
                type="number"
                value={@form[:height_cm].value}
                min="1"
                step="0.1"
                class="gb-input gb-input--stat mt-2"
              />
              <.error :for={msg <- @form[:height_cm].errors}>{translate_error(msg)}</.error>
            </div>
          </div>

          <div>
            <label for="profile_weight_kg" class="type-label">Current weight (kg)</label>
            <input
              id="profile_weight_kg"
              name="profile[weight_kg]"
              type="number"
              value={@form[:weight_kg].value}
              min="1"
              step="0.1"
              class="gb-input gb-input--stat mt-2"
            />
            <.error :for={msg <- @form[:weight_kg].errors}>{translate_error(msg)}</.error>
          </div>

          <button type="submit" class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block">
            Save and continue
          </button>
        </.form>
      </div>
    </div>
    """
  end

  defp access_path(%{role: "athlete"} = user) do
    case Onboarding.next_path(user) do
      "/onboarding/body-stats" -> :ok
      path -> path
    end
  end

  defp access_path(user), do: Onboarding.next_path(user)

  defp current_profile(socket) do
    Profiles.get_user_profile_by_user(socket.assigns.current_user.id) ||
      %UserProfile{user_id: socket.assigns.current_user.id}
  end

  defp form_for(profile) do
    profile
    |> Profiles.change_user_profile()
    |> to_form(as: :profile)
  end
end
