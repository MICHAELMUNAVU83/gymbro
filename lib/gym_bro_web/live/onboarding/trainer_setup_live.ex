defmodule GymBroWeb.Onboarding.TrainerSetupLive do
  use GymBroWeb, :live_view

  alias GymBro.Onboarding
  alias GymBro.Profiles
  alias GymBro.Profiles.TrainerProfile

  @specializations [
    {"Strength", "strength"},
    {"Fat loss", "fat_loss"},
    {"Rehab", "rehab"},
    {"General coaching", "general"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case access_path(current_user) do
      :ok ->
        profile =
          Profiles.get_trainer_profile_by_user(current_user.id) ||
            %TrainerProfile{user_id: current_user.id, max_clients: 20}

        {:ok,
         socket
         |> assign(:form, form_for(profile))
         |> assign(:specializations, @specializations), layout: false}

      path ->
        {:ok, push_navigate(socket, to: path), layout: false}
    end
  end

  @impl true
  def handle_event("validate", %{"trainer_profile" => params}, socket) do
    profile = current_profile(socket)
    changeset = profile |> Profiles.change_trainer_profile(params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :form, to_form(changeset, as: :trainer_profile))}
  end

  def handle_event("save", %{"trainer_profile" => params}, socket) do
    case Profiles.upsert_trainer_profile(socket.assigns.current_user.id, params) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Trainer profile ready.")
         |> push_navigate(to: ~p"/trainer")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :trainer_profile))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="app-shell py-10">
      <.flash_group flash={@flash} />

      <div class="mx-auto max-w-xl">
        <p class="type-label">Trainer setup</p>
        <h1 class="mt-3 type-h1">Create your coaching identity</h1>
        <p class="mt-3 type-body text-text-muted">
          Add the details athletes should see before they trust you with their progress.
        </p>

        <.form
          for={@form}
          id="trainer-setup-form"
          phx-change="validate"
          phx-submit="save"
          class="mt-8 space-y-5"
        >
          <div>
            <label for="trainer_profile_bio" class="type-label">Bio</label>
            <textarea
              id="trainer_profile_bio"
              name="trainer_profile[bio]"
              rows="4"
              class="gb-input mt-2 min-h-[6rem]"
            >{@form[:bio].value}</textarea>
            <.error :for={msg <- @form[:bio].errors}>{translate_error(msg)}</.error>
          </div>

          <div>
            <label for="trainer_profile_specialization" class="type-label">Specialization</label>
            <select
              id="trainer_profile_specialization"
              name="trainer_profile[specialization]"
              class="gb-input mt-2"
            >
              <option value="">Choose a focus</option>
              {Phoenix.HTML.Form.options_for_select(@specializations, @form[:specialization].value)}
            </select>
            <.error :for={msg <- @form[:specialization].errors}>{translate_error(msg)}</.error>
          </div>

          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <div>
              <label for="trainer_profile_years_experience" class="type-label">Years experience</label>
              <input
                id="trainer_profile_years_experience"
                name="trainer_profile[years_experience]"
                type="number"
                value={@form[:years_experience].value}
                min="0"
                class="gb-input gb-input--stat mt-2"
              />
              <.error :for={msg <- @form[:years_experience].errors}>{translate_error(msg)}</.error>
            </div>

            <div>
              <label for="trainer_profile_max_clients" class="type-label">Max clients</label>
              <input
                id="trainer_profile_max_clients"
                name="trainer_profile[max_clients]"
                type="number"
                value={@form[:max_clients].value}
                min="1"
                class="gb-input gb-input--stat mt-2"
              />
              <.error :for={msg <- @form[:max_clients].errors}>{translate_error(msg)}</.error>
            </div>
          </div>

          <div>
            <label for="trainer_profile_certification" class="type-label">Certification</label>
            <input
              id="trainer_profile_certification"
              name="trainer_profile[certification]"
              type="text"
              value={@form[:certification].value}
              class="gb-input mt-2"
            />
            <.error :for={msg <- @form[:certification].errors}>{translate_error(msg)}</.error>
          </div>

          <button type="submit" class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block">
            Save and open dashboard
          </button>
        </.form>
      </div>
    </div>
    """
  end

  defp access_path(%{role: "trainer"} = user) do
    case Onboarding.next_path(user) do
      "/onboarding/trainer-setup" -> :ok
      path -> path
    end
  end

  defp access_path(user), do: Onboarding.next_path(user)

  defp current_profile(socket) do
    Profiles.get_trainer_profile_by_user(socket.assigns.current_user.id) ||
      %TrainerProfile{user_id: socket.assigns.current_user.id, max_clients: 20}
  end

  defp form_for(profile) do
    profile
    |> Profiles.change_trainer_profile()
    |> to_form(as: :trainer_profile)
  end
end
