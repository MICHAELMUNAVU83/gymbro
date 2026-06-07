defmodule GymBroWeb.Trainer.ClientExerciseFormLive do
  use GymBroWeb, :live_view

  import GymBroWeb.Trainer.ClientProgramHelpers

  alias GymBro.Programs
  alias GymBro.Programs.Exercise
  alias GymBro.{Onboarding, Profiles, Trainer}

  @impl true
  def mount(%{"client_id" => client_id, "day_id" => day_id} = params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = Profiles.get_trainer_profile_by_user(current_user.id)

    cond do
      is_nil(profile) ->
        {:ok, push_navigate(socket, to: Onboarding.welcome_path(current_user)), layout: false}

      true ->
        case Trainer.get_managed_client_detail(current_user.id, client_id) do
          {:ok, detail} ->
            with {:ok, workout_day} <- find_workout_day(detail.program, day_id),
                 {:ok, editor} <- build_editor(socket.assigns.live_action, detail, workout_day, params) do
              {:ok,
               socket
               |> assign(:active_nav, :clients)
               |> assign(:page_title, exercise_form_title(editor))
               |> assign(:detail, detail)
               |> assign(:workout_day, workout_day)
               |> assign(:editor, editor)
               |> assign(:form, to_form(Programs.change_exercise(editor.exercise))),
               layout: {GymBroWeb.Layouts, :trainer_app}}
            else
              {:error, :not_found} ->
                {:ok,
                 socket
                 |> put_flash(:error, "That workout day or exercise could not be found anymore.")
                 |> push_navigate(to: ~p"/trainer/clients/#{client_id}/days/#{day_id}"),
                 layout: false}
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
  def handle_event("validate_exercise", %{"exercise" => params}, socket) do
    changeset =
      socket.assigns.editor.exercise
      |> Programs.change_exercise(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save_exercise", %{"exercise" => params}, socket) do
    editor = socket.assigns.editor
    current_user = socket.assigns.current_user
    client_id = socket.assigns.detail.client.id
    day_id = socket.assigns.workout_day.id

    result =
      case editor.mode do
        :new ->
          Trainer.add_exercise_to_client_day(
            current_user.id,
            client_id,
            editor.workout_day_id,
            params
          )

        :edit ->
          Trainer.update_client_exercise(current_user.id, client_id, editor.exercise.id, params)
      end

    case result do
      {:ok, _exercise} ->
        {:noreply,
         socket
         |> put_flash(:info, success_message(editor.mode))
         |> push_navigate(to: ~p"/trainer/clients/#{client_id}/days/#{day_id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "This client is not currently editable.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "That exercise could not be found anymore.")
         |> push_navigate(to: ~p"/trainer/clients/#{client_id}/days/#{day_id}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.back navigate={~p"/trainer/clients/#{@detail.client.id}/days/#{@workout_day.id}"}>
        {@workout_day.day_label || "Workout day"}
      </.back>

      <header>
        <p class="type-label inline-flex items-center gap-1.5">
          <.icon name="hero-pencil-square-mini" class="h-3.5 w-3.5 text-accent" />
          Week {@workout_day.week_number} · Day {@workout_day.day_number}
        </p>
        <h1 class="mt-2 type-h1">{exercise_form_title(@editor)}</h1>
      </header>

      <.form
        id="trainer-exercise-form"
        for={@form}
        phx-change="validate_exercise"
        phx-submit="save_exercise"
        class="gb-card space-y-3"
      >
        <.input field={@form[:name]} type="text" label="Exercise name" />
        <div class="grid grid-cols-2 gap-3">
          <.input field={@form[:sets]} type="number" label="Sets" stat />
          <.input field={@form[:reps]} type="text" label="Reps" placeholder="8-10" />
        </div>
        <div class="grid grid-cols-2 gap-3">
          <.input field={@form[:rest_seconds]} type="number" label="Rest seconds" stat />
          <.input field={@form[:weight_kg]} type="number" step="0.1" label="Weight kg" stat />
        </div>
        <.input field={@form[:notes]} type="textarea" label="Exercise notes" />
        <.input field={@form[:visual_guide]} type="textarea" label="Visual guide" />
        <.input field={@form[:trainer_notes]} type="textarea" label="Trainer notes" />
        <.input field={@form[:is_timed]} type="checkbox" label="Timed exercise" />
        <.input field={@form[:duration_seconds]} type="number" label="Duration seconds" stat />

        <div class="flex flex-wrap gap-3 pt-2">
          <button type="submit" class="gb-btn gb-btn--primary gb-btn--block">
            {exercise_submit_label(@editor)}
          </button>
          <.link
            navigate={~p"/trainer/clients/#{@detail.client.id}/days/#{@workout_day.id}"}
            class="gb-btn gb-btn--ghost gb-btn--block"
          >
            Cancel
          </.link>
        </div>
      </.form>
    </div>
    """
  end

  defp build_editor(:new, _detail, workout_day, _params) do
    exercise = %Exercise{
      workout_day_id: workout_day.id,
      position: Programs.next_exercise_position(workout_day.id)
    }

    {:ok, %{mode: :new, workout_day_id: workout_day.id, exercise: exercise}}
  end

  defp build_editor(:edit, detail, _workout_day, %{"exercise_id" => exercise_id}) do
    case find_exercise(detail.program, exercise_id) do
      {:ok, exercise} ->
        {:ok, %{mode: :edit, workout_day_id: exercise.workout_day_id, exercise: exercise}}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp find_workout_day(nil, _day_id), do: {:error, :not_found}

  defp find_workout_day(program, day_id) do
    case Enum.find(program.workout_days, &(to_string(&1.id) == to_string(day_id))) do
      nil -> {:error, :not_found}
      workout_day -> {:ok, workout_day}
    end
  end

  defp find_exercise(nil, _exercise_id), do: {:error, :not_found}

  defp find_exercise(program, exercise_id) do
    program.workout_days
    |> Enum.find_value(fn workout_day ->
      Enum.find(workout_day.exercises, &(to_string(&1.id) == to_string(exercise_id)))
    end)
    |> case do
      nil -> {:error, :not_found}
      exercise -> {:ok, exercise}
    end
  end
end
