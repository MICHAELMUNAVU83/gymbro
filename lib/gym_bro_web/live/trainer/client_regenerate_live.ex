defmodule GymBroWeb.Trainer.ClientRegenerateLive do
  use GymBroWeb, :live_view

  import GymBroWeb.Trainer.ClientProgramHelpers

  alias GymBro.{Onboarding, Profiles, Trainer}

  @rest_day_labels [
    {1, "Mon"},
    {2, "Tue"},
    {3, "Wed"},
    {4, "Thu"},
    {5, "Fri"},
    {6, "Sat"},
    {7, "Sun"}
  ]

  @impl true
  def mount(%{"client_id" => client_id}, _session, socket) do
    current_user = socket.assigns.current_user
    trainer_profile = Profiles.get_trainer_profile_by_user(current_user.id)

    cond do
      is_nil(trainer_profile) ->
        {:ok, push_navigate(socket, to: Onboarding.welcome_path(current_user)), layout: false}

      true ->
        case Trainer.get_managed_client_detail(current_user.id, client_id) do
          {:ok, %{profile: nil} = detail} ->
            {:ok,
             socket
             |> put_flash(
               :error,
               "This client needs a completed profile before AI can build a plan."
             )
             |> push_navigate(to: ~p"/trainer/clients/#{detail.client.id}?tab=program"),
             layout: false}

          {:ok, detail} ->
            {:ok,
             socket
             |> assign(:active_nav, :clients)
             |> assign(:page_title, "Configure & regenerate")
             |> assign(:detail, detail)
             |> assign(:regenerating, false)
             |> assign(:trainer_notes, "")
             |> assign(:rest_day_labels, @rest_day_labels)
             |> assign_form(Trainer.change_client_profile(detail.profile)),
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
  def handle_event("validate", params, socket) do
    profile_params = profile_params(params)

    changeset =
      socket.assigns.detail.profile
      |> Trainer.change_client_profile(profile_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign_form(changeset)
     |> assign(:trainer_notes, params["trainer_notes"] || "")}
  end

  def handle_event("regenerate", params, socket) do
    profile_params = profile_params(params)
    trainer_notes = params["trainer_notes"] || ""
    trainer_id = socket.assigns.current_user.id
    client_id = socket.assigns.detail.client.id

    changeset =
      socket.assigns.detail.profile
      |> Trainer.change_client_profile(profile_params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      {:noreply,
       socket
       |> assign(:regenerating, true)
       |> assign(:trainer_notes, trainer_notes)
       |> assign_form(changeset)
       |> start_async(:regenerate, fn ->
         Trainer.reconfigure_and_regenerate_client_program(
           trainer_id,
           client_id,
           profile_params,
           trainer_notes
         )
       end)}
    else
      {:noreply,
       socket
       |> assign_form(changeset)
       |> assign(:trainer_notes, trainer_notes)
       |> put_flash(:error, "Check the highlighted fields before regenerating.")}
    end
  end

  @impl true
  def handle_async(:regenerate, {:ok, {:ok, _program}}, socket) do
    client_id = socket.assigns.detail.client.id

    {:noreply,
     socket
     |> assign(:regenerating, false)
     |> put_flash(:info, "Profile saved and a fresh AI program is ready.")
     |> push_navigate(to: ~p"/trainer/clients/#{client_id}?tab=program")}
  end

  def handle_async(:regenerate, {:ok, {:error, %Ecto.Changeset{} = changeset}}, socket) do
    {:noreply,
     socket
     |> assign(:regenerating, false)
     |> assign_form(Map.put(changeset, :action, :validate))
     |> put_flash(:error, "Check the highlighted fields before regenerating.")}
  end

  def handle_async(:regenerate, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:regenerating, false)
     |> put_flash(:error, regeneration_error(reason))}
  end

  def handle_async(:regenerate, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:regenerating, false)
     |> put_flash(:error, "Plan regeneration stopped unexpectedly. Please try again.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.back navigate={~p"/trainer/clients/#{@detail.client.id}?tab=program"}>
        {display_name(@detail.client.email)}'s plan
      </.back>

      <header>
        <p class="type-label">AI refresh</p>
        <h1 class="mt-2 type-h1">Configure &amp; regenerate {display_name(@detail.client.email)}'s plan</h1>
        <p class="mt-3 max-w-[60ch] type-body text-text-muted">
          Update the athlete's targets and training preferences, add any coaching notes, and generate a fresh AI program built around them. These values are saved to the client's profile.
        </p>
      </header>

      <.form
        id="regeneration-form"
        for={@form}
        phx-change="validate"
        phx-submit="regenerate"
        class="space-y-8"
      >
        <section class="gb-card space-y-4">
          <.section_head icon="hero-scale-mini">Body &amp; goals</.section_head>
          <div class="grid gap-3 sm:grid-cols-2">
            <.input field={@form[:weight_kg]} type="number" step="0.1" label="Current weight (kg)" stat />
            <.input field={@form[:goal_weight_kg]} type="number" step="0.1" label="Target weight (kg)" stat />
            <.input field={@form[:height_cm]} type="number" step="0.1" label="Height (cm)" stat />
            <.input field={@form[:age]} type="number" label="Age" stat />
            <.input
              field={@form[:goal]}
              type="select"
              label="Primary goal"
              options={goal_options()}
            />
            <.input
              field={@form[:fitness_level]}
              type="select"
              label="Fitness level"
              options={fitness_level_options()}
            />
          </div>
        </section>

        <section class="gb-card space-y-4">
          <.section_head icon="hero-calendar-days-mini">Schedule &amp; structure</.section_head>
          <div class="grid gap-3 sm:grid-cols-2">
            <.input
              field={@form[:days_per_week]}
              type="select"
              label="Training days per week"
              options={days_per_week_options()}
            />
            <.input
              field={@form[:preferred_session_minutes]}
              type="select"
              label="Session length (min)"
              options={session_minutes_options()}
            />
            <.input
              field={@form[:preferred_exercises_per_day]}
              type="select"
              label="Exercises per day"
              options={exercises_per_day_options()}
            />
            <.input
              field={@form[:preferred_block_weeks]}
              type="select"
              label="Block length (weeks)"
              options={block_weeks_options()}
            />
            <.input
              field={@form[:equipment]}
              type="select"
              label="Equipment access"
              options={equipment_options()}
            />
          </div>

          <fieldset>
            <p class="type-label">Days off (rest days)</p>
            <p class="mt-1 type-body-sm text-text-muted">
              Pick the rest days. You need exactly {7 - (days_per_week_value(@form) || 0)} for the selected training frequency.
            </p>
            <div class="mt-3 flex flex-wrap gap-2">
              <label
                :for={{day_number, label} <- @rest_day_labels}
                class={rest_day_chip_class(rest_day_selected?(@form, day_number))}
              >
                <input
                  type="checkbox"
                  name="user_profile[preferred_rest_days][]"
                  value={day_number}
                  checked={rest_day_selected?(@form, day_number)}
                  class="sr-only"
                />
                {label}
              </label>
            </div>
            <input type="hidden" name="user_profile[preferred_rest_days][]" value="" />
            <.error :for={msg <- rest_day_errors(@form)}>{msg}</.error>
          </fieldset>
        </section>

        <section class="gb-card space-y-3">
          <.section_head icon="hero-megaphone-mini">Trainer notes for AI</.section_head>
          <textarea
            name="trainer_notes"
            rows="4"
            class="gb-input"
            placeholder="Example: Reduce axial loading, keep sessions under 50 minutes, bias glute work, and leave one lower day as machine dominant."
          >{@trainer_notes}</textarea>
        </section>

        <button type="submit" class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block" disabled={@regenerating}>
          <.icon name="hero-sparkles-solid" class="h-4 w-4" />
          {if @regenerating, do: "Saving & regenerating…", else: "Save & regenerate program"}
        </button>
      </.form>
    </div>
    """
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp profile_params(params) do
    Map.get(params, "user_profile", %{})
  end

  defp days_per_week_value(form) do
    case form[:days_per_week].value do
      value when is_integer(value) -> value
      value when is_binary(value) -> String.to_integer(value)
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp rest_day_selected?(form, day_number) do
    form[:preferred_rest_days].value
    |> List.wrap()
    |> Enum.any?(&(to_string(&1) == to_string(day_number)))
  end

  defp rest_day_errors(form) do
    form[:preferred_rest_days].errors
    |> Enum.map(fn {msg, opts} -> GymBroWeb.CoreComponents.translate_error({msg, opts}) end)
  end

  defp rest_day_chip_class(true),
    do: "cursor-pointer rounded-pill border border-accent bg-accent-soft px-4 py-2 text-sm font-semibold text-accent"

  defp rest_day_chip_class(false),
    do:
      "cursor-pointer rounded-pill border border-border bg-surface px-4 py-2 text-sm font-semibold text-text-muted hover:text-text"

  defp goal_options do
    [{"Weight loss", "weight_loss"}, {"Muscle gain", "muscle_gain"}, {"Maintenance", "maintenance"}]
  end

  defp fitness_level_options do
    [{"Beginner", "beginner"}, {"Intermediate", "intermediate"}, {"Advanced", "advanced"}]
  end

  defp equipment_options do
    [{"Full gym", "gym"}, {"Home", "home"}, {"Minimal", "minimal"}]
  end

  defp days_per_week_options do
    Enum.map([3, 4, 5], &{"#{&1} days", &1})
  end

  defp session_minutes_options do
    Enum.map([30, 45, 60, 75, 90], &{"#{&1} min", &1})
  end

  defp exercises_per_day_options do
    Enum.map([3, 4, 5, 6], &{"#{&1} exercises", &1})
  end

  defp block_weeks_options do
    Enum.map(3..16, &{"#{&1} weeks", &1})
  end
end
