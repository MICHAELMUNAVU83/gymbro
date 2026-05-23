defmodule GymBroWeb.Onboarding.GoalsLive do
  use GymBroWeb, :live_view

  alias GymBro.Onboarding
  alias GymBro.Profiles
  alias GymBro.Profiles.UserProfile

  @goal_options [
    {"Weight loss", "weight_loss"},
    {"Muscle gain", "muscle_gain"},
    {"Maintenance", "maintenance"}
  ]

  @fitness_options [
    {"Beginner", "beginner"},
    {"Intermediate", "intermediate"},
    {"Advanced", "advanced"}
  ]

  @equipment_options [
    {"Gym access", "gym"},
    {"Home gym", "home"},
    {"Minimal equipment", "minimal"}
  ]

  @days_options [{"3 days", 3}, {"4 days", 4}, {"5 days", 5}]
  @exercises_per_day_options [
    {"3 exercises", 3},
    {"4 exercises", 4},
    {"5 exercises", 5},
    {"6 exercises", 6}
  ]
  @session_length_options [
    {"30 min", 30},
    {"45 min", 45},
    {"60 min", 60},
    {"75 min", 75},
    {"90 min", 90}
  ]

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case access_path(current_user) do
      :ok ->
        profile =
          Profiles.get_user_profile_by_user(current_user.id) ||
            %UserProfile{user_id: current_user.id}

        {:ok,
         socket
         |> assign(:form, form_for(profile))
         |> assign(:goal_options, @goal_options)
         |> assign(:fitness_options, @fitness_options)
         |> assign(:equipment_options, @equipment_options)
         |> assign(:days_options, @days_options)
         |> assign(:exercises_per_day_options, @exercises_per_day_options)
         |> assign(:session_length_options, @session_length_options), layout: false}

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
        {:noreply, push_navigate(socket, to: ~p"/onboarding/generating")}

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
        <p class="type-label">Step 2 of 3</p>
        <h1 class="mt-3 type-h1">Training goals</h1>
        <p class="mt-3 type-body text-text-muted">
          Tell GymBro what you want from this block and how you prefer to train.
        </p>

        <.form
          for={@form}
          id="goals-form"
          phx-change="validate"
          phx-submit="save"
          class="mt-8 space-y-5"
        >
          <div>
            <label for="profile_goal" class="type-label">Primary goal</label>
            <select id="profile_goal" name="profile[goal]" class="gb-input mt-2">
              <option value="">Choose a goal</option>
              {Phoenix.HTML.Form.options_for_select(@goal_options, @form[:goal].value)}
            </select>
            <.error :for={msg <- @form[:goal].errors}>{translate_error(msg)}</.error>
          </div>

          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <div>
              <label for="profile_days_per_week" class="type-label">Days per week</label>
              <select id="profile_days_per_week" name="profile[days_per_week]" class="gb-input mt-2">
                <option value="">Choose your schedule</option>
                {Phoenix.HTML.Form.options_for_select(@days_options, @form[:days_per_week].value)}
              </select>
              <.error :for={msg <- @form[:days_per_week].errors}>{translate_error(msg)}</.error>
            </div>

            <div>
              <label for="profile_preferred_session_minutes" class="type-label">Time per day</label>
              <select
                id="profile_preferred_session_minutes"
                name="profile[preferred_session_minutes]"
                class="gb-input mt-2"
              >
                <option value="">Choose a session length</option>
                {Phoenix.HTML.Form.options_for_select(
                  @session_length_options,
                  @form[:preferred_session_minutes].value
                )}
              </select>
              <.error :for={msg <- @form[:preferred_session_minutes].errors}>
                {translate_error(msg)}
              </.error>
            </div>
          </div>

          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <div>
              <label for="profile_preferred_exercises_per_day" class="type-label">
                Exercises per day
              </label>
              <select
                id="profile_preferred_exercises_per_day"
                name="profile[preferred_exercises_per_day]"
                class="gb-input mt-2"
              >
                <option value="">Choose a target</option>
                {Phoenix.HTML.Form.options_for_select(
                  @exercises_per_day_options,
                  @form[:preferred_exercises_per_day].value
                )}
              </select>
              <.error :for={msg <- @form[:preferred_exercises_per_day].errors}>
                {translate_error(msg)}
              </.error>
            </div>
          </div>

          <div>
            <p class="type-label">Preferred rest days</p>
            <p class="mt-2 type-body-sm text-text-muted">
              Pick exactly {required_rest_day_count(@form[:days_per_week].value)} day(s) to keep open for recovery.
            </p>
            <div class="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
              <label
                :for={{label, value} <- rest_day_options()}
                class="flex items-center gap-3 rounded-xl border border-border px-4 py-3 text-sm text-text"
              >
                <input
                  type="checkbox"
                  name="profile[preferred_rest_days][]"
                  value={value}
                  checked={value in selected_rest_days(@form[:preferred_rest_days].value)}
                  class="h-4 w-4 rounded border-border text-accent focus:ring-2 focus:ring-accent focus:ring-offset-0"
                />
                <span>{label}</span>
              </label>
            </div>
            <input type="hidden" name="profile[preferred_rest_days][]" value="" />
            <.error :for={msg <- @form[:preferred_rest_days].errors}>{translate_error(msg)}</.error>
          </div>

          <div>
            <label for="profile_goal_weight_kg" class="type-label">Goal weight (kg)</label>
            <input
              id="profile_goal_weight_kg"
              name="profile[goal_weight_kg]"
              type="number"
              value={@form[:goal_weight_kg].value}
              min="1"
              step="0.1"
              class="gb-input gb-input--stat mt-2"
            />
            <.error :for={msg <- @form[:goal_weight_kg].errors}>{translate_error(msg)}</.error>
          </div>

          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <div>
              <label for="profile_fitness_level" class="type-label">Fitness level</label>
              <select id="profile_fitness_level" name="profile[fitness_level]" class="gb-input mt-2">
                <option value="">Choose a level</option>
                {Phoenix.HTML.Form.options_for_select(@fitness_options, @form[:fitness_level].value)}
              </select>
              <.error :for={msg <- @form[:fitness_level].errors}>{translate_error(msg)}</.error>
            </div>
          </div>

          <div>
            <label for="profile_equipment" class="type-label">Equipment access</label>
            <select id="profile_equipment" name="profile[equipment]" class="gb-input mt-2">
              <option value="">Choose your setup</option>
              {Phoenix.HTML.Form.options_for_select(@equipment_options, @form[:equipment].value)}
            </select>
            <.error :for={msg <- @form[:equipment].errors}>{translate_error(msg)}</.error>
          </div>

          <button type="submit" class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block">
            Continue to plan generation
          </button>
        </.form>
      </div>
    </div>
    """
  end

  defp access_path(%{role: "athlete"} = user) do
    case Onboarding.next_path(user) do
      "/onboarding/goals" -> :ok
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

  defp rest_day_options do
    [
      {"Monday", 1},
      {"Tuesday", 2},
      {"Wednesday", 3},
      {"Thursday", 4},
      {"Friday", 5},
      {"Saturday", 6},
      {"Sunday", 7}
    ]
  end

  defp selected_rest_days(rest_days) when is_list(rest_days) do
    rest_days
    |> Enum.map(fn
      day when is_integer(day) ->
        day

      day when is_binary(day) ->
        case Integer.parse(day) do
          {value, _} -> value
          :error -> nil
        end

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp selected_rest_days(_rest_days), do: []

  defp required_rest_day_count(days_per_week) do
    case parse_integer(days_per_week) do
      value when value in [3, 4, 5] -> 7 - value
      _ -> 2
    end
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _} -> parsed
      :error -> nil
    end
  end

  defp parse_integer(_value), do: nil
end
