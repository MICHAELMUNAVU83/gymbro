defmodule GymBroWeb.Athlete.SettingsLive do
  use GymBroWeb, :live_view

  alias GymBro.{Onboarding, Profiles, Programs}
  alias GymBro.Profiles.UserProfile

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case Onboarding.next_path(current_user) do
      "/" ->
        profile =
          Profiles.get_user_profile_by_user(current_user.id) ||
            %UserProfile{user_id: current_user.id}

        {:ok,
         socket
         |> assign(:active_nav, :settings)
         |> assign(:page_title, "Training Settings")
         |> assign(:profile, profile)
         |> assign(:program, active_or_latest_program(current_user.id))
         |> assign(:draft_profile_params, nil)
         |> assign(:regenerating, false)
         |> assign(:profile_form, profile_form(profile))}

      path ->
        {:ok, push_navigate(socket, to: path), layout: false}
    end
  end

  @impl true
  def handle_event("validate_profile", %{"profile" => params}, socket) do
    changeset =
      socket.assigns.profile
      |> Profiles.change_user_profile(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:draft_profile_params, params)
     |> assign(:profile_form, to_form(changeset, as: :profile))}
  end

  def handle_event("save_profile", %{"profile" => params} = payload, socket) do
    case Profiles.upsert_user_profile(socket.assigns.current_user.id, params) do
      {:ok, profile} ->
        handle_profile_submit(socket, profile, Map.get(payload, "intent", "save"))

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset, as: :profile))}
    end
  end

  def handle_event("regenerate_plan", _params, socket) do
    params = socket.assigns.draft_profile_params || profile_params(socket.assigns.profile)

    case Profiles.upsert_user_profile(socket.assigns.current_user.id, params) do
      {:ok, profile} ->
        current_user = socket.assigns.current_user

        {:noreply,
         socket
         |> assign(:profile, profile)
         |> assign(:draft_profile_params, nil)
         |> assign(:profile_form, profile_form(profile))
         |> assign(:regenerating, true)
         |> start_async(:regenerate_plan, fn ->
           Programs.regenerate_ai_program_for_user(current_user.id, current_user.id)
         end)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:profile_form, to_form(Map.put(changeset, :action, :validate), as: :profile))
         |> put_flash(:error, "Please fix the training settings before regenerating.")}
    end
  end

  @impl true
  def handle_async(:regenerate_plan, {:ok, {:ok, program}}, socket) do
    profile =
      Profiles.get_user_profile_by_user(socket.assigns.current_user.id) || socket.assigns.profile

    {:noreply,
     socket
     |> assign(:profile, profile)
     |> assign(:program, program)
     |> assign(:profile_form, profile_form(profile))
     |> assign(:regenerating, false)
     |> put_flash(:info, "Fresh #{program.total_weeks}-week plan generated.")}
  end

  def handle_async(:regenerate_plan, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:regenerating, false)
     |> put_flash(:error, regeneration_error(reason))}
  end

  def handle_async(:regenerate_plan, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:regenerating, false)
     |> put_flash(:error, "Plan regeneration stopped unexpectedly. Please try again.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="gb-grid">
      <div class="gb-grid__main space-y-8">
        <header>
          <p class="type-label">Training settings</p>
          <h1 class="mt-2 type-h1">Tune the next training block.</h1>
          <p class="mt-3 max-w-[60ch] type-body text-text-muted">
            Update the inputs your AI plan is built from, then either save them or regenerate a fresh block in one step.
          </p>
        </header>

        <.callout label="How regeneration works">
          Regenerating pauses the current active program and replaces it with a new {selected_block_weeks(
            @profile_form
          )}-week AI plan built from the form values you submit here.
        </.callout>

        <section class="gb-card">
          <header class="flex items-start justify-between gap-4">
            <div>
              <.section_head icon="hero-adjustments-horizontal-mini">Profile inputs</.section_head>
              <h2 class="mt-2 type-h2">What shapes your program</h2>
              <p class="mt-2 max-w-[60ch] type-body-sm">
                Start with your goal, schedule, and preferred session length, then keep the body metrics underneath up to date.
              </p>
            </div>
            <.link href={~p"/users/settings"} class="gb-btn gb-btn--secondary gb-btn--sm">
              <.icon name="hero-user-circle-mini" class="h-4 w-4" /> Account security
            </.link>
          </header>

          <.form
            id="athlete-settings-form"
            for={@profile_form}
            phx-change="validate_profile"
            phx-submit="save_profile"
            class="mt-6 space-y-4"
          >
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <.input
                field={@profile_form[:goal]}
                type="select"
                label="Goal"
                options={goal_options()}
              />
              <.input
                field={@profile_form[:days_per_week]}
                type="select"
                label="Training days per week"
                options={days_per_week_options()}
              />
              <.input
                field={@profile_form[:preferred_session_minutes]}
                type="select"
                label="Time per day"
                options={session_length_options()}
              />
              <.input
                field={@profile_form[:preferred_block_weeks]}
                type="select"
                label="Block length"
                options={block_weeks_options()}
              />
              <.input
                field={@profile_form[:preferred_exercises_per_day]}
                type="select"
                label="Exercises per day"
                options={exercises_per_day_options()}
                prompt="Choose a target"
              />
              <.input
                field={@profile_form[:equipment]}
                type="select"
                label="Equipment"
                options={equipment_options()}
              />
              <.input
                field={@profile_form[:fitness_level]}
                type="select"
                label="Fitness level"
                options={fitness_level_options()}
              />
              <.input
                field={@profile_form[:goal_weight_kg]}
                type="number"
                step="0.1"
                min="0"
                label="Goal weight kg"
              />
            </div>

            <hr class="gb-divider" />

            <div class="space-y-3">
              <div>
                <p class="type-label">Preferred rest days</p>
                <p class="mt-1 type-body-sm text-text-muted">
                  Pick exactly {required_rest_day_count(@profile_form[:days_per_week].value)} day(s) to leave for recovery.
                </p>
              </div>
              <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <label
                  :for={{label, value} <- rest_day_options()}
                  class="flex items-center gap-3 rounded-xl border border-border px-4 py-3 text-sm text-text"
                >
                  <input
                    type="checkbox"
                    name="profile[preferred_rest_days][]"
                    value={value}
                    checked={value in selected_rest_days(@profile_form[:preferred_rest_days].value)}
                    class="h-4 w-4 rounded border-border text-accent focus:ring-2 focus:ring-accent focus:ring-offset-0"
                  />
                  <span>{label}</span>
                </label>
              </div>
              <input type="hidden" name="profile[preferred_rest_days][]" value="" />
              <.error :for={msg <- @profile_form[:preferred_rest_days].errors}>
                {translate_error(msg)}
              </.error>
            </div>

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <.input field={@profile_form[:age]} type="number" min="1" label="Age" />
              <.input
                field={@profile_form[:height_cm]}
                type="number"
                step="0.1"
                min="0"
                label="Height cm"
              />
              <.input
                field={@profile_form[:weight_kg]}
                type="number"
                step="0.1"
                min="0"
                label="Current weight kg"
              />
            </div>

            <div class="flex flex-col gap-3 sm:flex-row">
              <.button type="submit" variant="secondary" size="lg">
                Save training settings
              </.button>
              <button
                id="regenerate-plan-button"
                type="button"
                phx-click="regenerate_plan"
                disabled={@regenerating}
                class="gb-btn gb-btn--primary gb-btn--lg phx-click-loading:opacity-75"
              >
                <.icon name="hero-arrow-path-mini" class="h-4 w-4" />
                {if @regenerating, do: "Saving and regenerating...", else: "Save and regenerate plan"}
              </button>
            </div>
          </.form>
        </section>

        <section class="gb-card gb-card--accent">
          <header class="flex items-start justify-between gap-4">
            <div>
              <.section_head icon="hero-sparkles-mini">Plan regeneration</.section_head>
              <h2 class="mt-2 type-h2">
                {if @regenerating, do: "Building your next block", else: program_heading(@program)}
              </h2>
              <p class="mt-2 max-w-[60ch] type-body-sm">
                {if @regenerating,
                  do:
                    "This usually takes a few seconds. We are saving your current settings and generating the new plan now.",
                  else: program_subtitle(@program)}
              </p>
            </div>
            <span :if={@regenerating} class="gb-pill gb-pill--accent">AI in progress</span>
          </header>

          <div :if={@regenerating} class="mt-6 space-y-4">
            <div class="h-1 overflow-hidden rounded-pill bg-surface-alt">
              <div class="h-full w-3/4 animate-pulse rounded-pill bg-accent"></div>
            </div>
            <div class="grid grid-cols-3 gap-3 type-label">
              <div>Settings saved</div>
              <div>Current plan paused</div>
              <div>New block building</div>
            </div>
          </div>

          <div :if={@program && not @regenerating} class="mt-6">
            <.stat_row>
              <:item label="Block length">{@program.total_weeks} weeks</:item>
              <:item label="Current phase">
                {@program.phase_name || "Phase #{@program.current_phase}"}
              </:item>
              <:item label="Source">{program_source_label(@program.source)}</:item>
            </.stat_row>
            <p class="mt-4 type-body-sm">
              Last generated {timestamp_label(@program.inserted_at)}.
            </p>
          </div>

          <p :if={is_nil(@program)} class="mt-6 type-body-sm">
            No program is attached yet. Save your profile and generate the first block from here.
          </p>
        </section>
      </div>
    </div>
    """
  end

  defp profile_form(profile),
    do: profile |> Profiles.change_user_profile() |> to_form(as: :profile)

  defp handle_profile_submit(socket, profile, "regenerate") do
    handle_profile_submit(socket, profile, "save")
  end

  defp handle_profile_submit(socket, profile, _intent) do
    {:noreply,
     socket
     |> assign(:profile, profile)
     |> assign(:draft_profile_params, nil)
     |> assign(:profile_form, profile_form(profile))
     |> put_flash(:info, "Training settings saved.")}
  end

  defp profile_params(profile) do
    %{
      "age" => profile.age && to_string(profile.age),
      "days_per_week" => profile.days_per_week && to_string(profile.days_per_week),
      "equipment" => profile.equipment,
      "fitness_level" => profile.fitness_level,
      "goal" => profile.goal,
      "goal_weight_kg" => profile.goal_weight_kg && format_decimal(profile.goal_weight_kg),
      "height_cm" => profile.height_cm && format_decimal(profile.height_cm),
      "preferred_block_weeks" =>
        profile.preferred_block_weeks && to_string(profile.preferred_block_weeks),
      "preferred_exercises_per_day" =>
        profile.preferred_exercises_per_day && to_string(profile.preferred_exercises_per_day),
      "preferred_rest_days" => Enum.map(List.wrap(profile.preferred_rest_days), &to_string/1),
      "preferred_session_minutes" =>
        profile.preferred_session_minutes && to_string(profile.preferred_session_minutes),
      "weight_kg" => profile.weight_kg && format_decimal(profile.weight_kg)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp format_decimal(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)
  defp format_decimal(value), do: to_string(value)

  defp active_or_latest_program(user_id) do
    Programs.get_active_program_for_user(user_id) || Programs.latest_program_for_user(user_id)
  end

  defp goal_options do
    [
      {"Muscle gain", "muscle_gain"},
      {"Weight loss", "weight_loss"},
      {"Maintenance", "maintenance"}
    ]
  end

  defp fitness_level_options do
    [
      {"Beginner", "beginner"},
      {"Intermediate", "intermediate"},
      {"Advanced", "advanced"}
    ]
  end

  defp days_per_week_options, do: [{"3 days", "3"}, {"4 days", "4"}, {"5 days", "5"}]

  defp block_weeks_options do
    Enum.map(3..16, fn weeks -> {"#{weeks} weeks", Integer.to_string(weeks)} end)
  end

  defp exercises_per_day_options,
    do: [{"3 exercises", "3"}, {"4 exercises", "4"}, {"5 exercises", "5"}, {"6 exercises", "6"}]

  defp session_length_options,
    do: [{"30 min", "30"}, {"45 min", "45"}, {"60 min", "60"}, {"75 min", "75"}, {"90 min", "90"}]

  defp equipment_options do
    [
      {"Gym", "gym"},
      {"Home gym", "home"},
      {"Minimal equipment", "minimal"}
    ]
  end

  defp program_heading(nil), do: "Generate your first plan"
  defp program_heading(program), do: program.name || "Active training block"

  defp program_subtitle(nil), do: "A fresh AI build will land here as your next training block."

  defp program_subtitle(program) do
    program.description || "Your current active training block is ready to review or replace."
  end

  defp program_source_label("ai"), do: "AI"
  defp program_source_label("trainer"), do: "Trainer"
  defp program_source_label("ai_trainer_edited"), do: "AI + trainer"
  defp program_source_label(source) when is_binary(source), do: String.replace(source, "_", " ")
  defp program_source_label(_source), do: "Unknown"

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

  defp timestamp_label(nil), do: "recently"
  defp timestamp_label(timestamp), do: Calendar.strftime(timestamp, "%b %-d, %Y")

  defp selected_block_weeks(profile_form) do
    case parse_integer(profile_form[:preferred_block_weeks].value) do
      value when is_integer(value) and value > 0 -> value
      _ -> 9
    end
  end

  defp regeneration_error(:missing_profile),
    do: "We need your training settings before we can build a plan."

  defp regeneration_error(:missing_openai_api_key),
    do: "OpenAI is not configured in this environment yet."

  defp regeneration_error(:openai_timeout),
    do: "Plan generation timed out. We shortened the request, so please try again."

  defp regeneration_error(:openai_rate_limited),
    do: "OpenAI is busy right now. Please try regenerating again in a moment."

  defp regeneration_error(_reason),
    do: "We could not regenerate the plan yet. Please try again."
end
