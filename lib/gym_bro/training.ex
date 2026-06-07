defmodule GymBro.Training do
  @moduledoc """
  The Training context.
  """

  import Ecto.Query, warn: false
  alias GymBro.Repo

  alias GymBro.Programs.{Exercise, WorkoutDay}
  alias GymBro.Training.{ExerciseLog, WorkoutClock, WorkoutSession}

  @progression_increment_kg 2.5

  @doc """
  Returns the list of workout_sessions.

  ## Examples

      iex> list_workout_sessions()
      [%WorkoutSession{}, ...]

  """
  def list_workout_sessions do
    Repo.all(from session in WorkoutSession, order_by: [desc: session.inserted_at])
  end

  def list_workout_sessions_for_user(user_id) do
    Repo.all(
      from session in WorkoutSession,
        where: session.user_id == ^user_id,
        order_by: [desc: session.inserted_at]
    )
  end

  def list_completed_workout_sessions_for_user_between(user_id, start_date, end_date) do
    start_of_day = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(end_date, ~T[23:59:59], "Etc/UTC")

    Repo.all(
      from session in WorkoutSession,
        where:
          session.user_id == ^user_id and
            session.status == "completed" and
            not is_nil(session.completed_at) and
            session.completed_at >= ^start_of_day and
            session.completed_at <= ^end_of_day,
        order_by: [asc: session.completed_at]
    )
  end

  def list_completed_workout_dates_for_user(user_id) do
    Repo.all(
      from session in WorkoutSession,
        where:
          session.user_id == ^user_id and session.status == "completed" and
            not is_nil(session.completed_at),
        select: fragment("date(?)", session.completed_at),
        distinct: true,
        order_by: [asc: fragment("date(?)", session.completed_at)]
    )
  end

  def get_active_workout_session_for_user(user_id) do
    Repo.one(
      from session in WorkoutSession,
        where: session.user_id == ^user_id and session.status == "active",
        order_by: [desc: session.inserted_at],
        limit: 1
    )
  end

  def get_active_workout_session_with_details_for_user(user_id) do
    case get_active_workout_session_for_user(user_id) do
      %WorkoutSession{} = session -> preload_workout_session(session)
      nil -> nil
    end
  end

  def apply_progression_recommendations_to_workout_day(user_id, %WorkoutDay{} = workout_day) do
    workout_day = preload_workout_day_exercises(workout_day)

    normalized_names =
      workout_day.exercises
      |> Enum.map(&normalize_exercise_name(&1.name))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    latest_logs_by_name = latest_completed_logs_by_exercise_name(user_id, normalized_names)

    exercises =
      Enum.map(workout_day.exercises, fn exercise ->
        latest_log = Map.get(latest_logs_by_name, normalize_exercise_name(exercise.name))
        apply_progression_to_exercise(exercise, latest_log)
      end)

    %{workout_day | exercises: exercises}
  end

  def latest_completed_workout_session_for_day(user_id, workout_day_id) do
    Repo.one(
      from session in WorkoutSession,
        where:
          session.user_id == ^user_id and session.workout_day_id == ^workout_day_id and
            session.status == "completed",
        order_by: [desc: session.completed_at, desc: session.inserted_at],
        limit: 1
    )
  end

  def get_workout_session_for_user!(user_id, session_id) do
    session_id
    |> workout_session_for_user_query(user_id)
    |> Repo.one!()
    |> preload_workout_session()
  end

  def get_or_start_workout_session(user_id, workout_day_id) do
    case get_active_workout_session_for_user(user_id) do
      %WorkoutSession{workout_day_id: ^workout_day_id} = session ->
        {:ok, preload_workout_session(session)}

      %WorkoutSession{} = session ->
        {:error, {:active_session_exists, preload_workout_session(session)}}

      nil ->
        case create_workout_session(%{
               user_id: user_id,
               workout_day_id: workout_day_id,
               started_at: DateTime.utc_now() |> DateTime.truncate(:second),
               status: "active"
             }) do
          {:ok, session} ->
            ensure_workout_clock(session.id, session.started_at)

            broadcast_client_session_event(user_id, :session_started, %{
              session_id: session.id,
              started_at: session.started_at,
              status: session.status,
              workout_day_id: session.workout_day_id
            })

            {:ok, preload_workout_session(session)}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def complete_workout_session(%WorkoutSession{} = workout_session, attrs \\ %{}) do
    completed_at = DateTime.utc_now() |> DateTime.truncate(:second)

    duration_seconds =
      case workout_session.started_at do
        %DateTime{} = started_at -> max(DateTime.diff(completed_at, started_at, :second), 1)
        _ -> nil
      end

    attrs =
      attrs
      |> Map.new()
      |> Map.put(:status, "completed")
      |> Map.put_new(:completed_at, completed_at)
      |> maybe_put_duration(duration_seconds)

    case update_workout_session(workout_session, attrs) do
      {:ok, session} ->
        stop_workout_clock(session.id)

        broadcast_client_session_event(session.user_id, :session_completed, %{
          completed_at: session.completed_at,
          duration_seconds: session.duration_seconds,
          session_id: session.id,
          status: session.status,
          workout_day_id: session.workout_day_id
        })

        {:ok, session}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def log_exercise_set(%WorkoutSession{} = workout_session, %Exercise{} = exercise, attrs \\ %{}) do
    if exercise.workout_day_id != workout_session.workout_day_id do
      {:error, :exercise_not_in_session}
    else
      attrs = Map.new(attrs)

      set_number =
        attrs[:set_number] ||
          attrs["set_number"] ||
          next_set_number(workout_session.id, exercise.id)

      attrs =
        normalize_param_keys(attrs, %{
          exercise_id: exercise.id,
          set_number: set_number,
          workout_session_id: workout_session.id
        })

      with {:ok, log} <- create_exercise_log(attrs) do
        broadcast_client_session_event(workout_session.user_id, :set_logged, %{
          exercise_id: exercise.id,
          exercise_name: exercise.name,
          log: log_payload(log),
          session_id: workout_session.id,
          workout_day_id: workout_session.workout_day_id
        })

        {:ok, log}
      end
    end
  end

  def workout_topic(%WorkoutSession{id: session_id}), do: workout_topic(session_id)
  def workout_topic(session_id), do: "workout:#{session_id}"

  def client_session_topic(user_id), do: "client_session:#{user_id}"

  def subscribe_to_workout(session_id) do
    Phoenix.PubSub.subscribe(GymBro.PubSub, workout_topic(session_id))
  end

  def ensure_workout_clock(session_id, started_at) do
    WorkoutClock.ensure_started(session_id, started_at)
  end

  def stop_workout_clock(session_id) do
    WorkoutClock.stop(session_id)
  end

  def subscribe_to_client_session(user_id) do
    Phoenix.PubSub.subscribe(GymBro.PubSub, client_session_topic(user_id))
  end

  def broadcast_workout_event(session_id, event, payload) do
    Phoenix.PubSub.broadcast(
      GymBro.PubSub,
      workout_topic(session_id),
      {:workout_event, event, payload}
    )
  end

  def broadcast_client_session_event(user_id, event, payload) do
    Phoenix.PubSub.broadcast(
      GymBro.PubSub,
      client_session_topic(user_id),
      {:client_session_event, event, payload}
    )
  end

  @doc """
  Gets a single workout_session.

  Raises `Ecto.NoResultsError` if the Workout session does not exist.

  ## Examples

      iex> get_workout_session!(123)
      %WorkoutSession{}

      iex> get_workout_session!(456)
      ** (Ecto.NoResultsError)

  """
  def get_workout_session!(id), do: Repo.get!(WorkoutSession, id)

  @doc """
  Creates a workout_session.

  ## Examples

      iex> create_workout_session(%{field: value})
      {:ok, %WorkoutSession{}}

      iex> create_workout_session(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_workout_session(attrs \\ %{}) do
    %WorkoutSession{}
    |> WorkoutSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a workout_session.

  ## Examples

      iex> update_workout_session(workout_session, %{field: new_value})
      {:ok, %WorkoutSession{}}

      iex> update_workout_session(workout_session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_workout_session(%WorkoutSession{} = workout_session, attrs) do
    workout_session
    |> WorkoutSession.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a workout_session.

  ## Examples

      iex> delete_workout_session(workout_session)
      {:ok, %WorkoutSession{}}

      iex> delete_workout_session(workout_session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_workout_session(%WorkoutSession{} = workout_session) do
    Repo.delete(workout_session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking workout_session changes.

  ## Examples

      iex> change_workout_session(workout_session)
      %Ecto.Changeset{data: %WorkoutSession{}}

  """
  def change_workout_session(%WorkoutSession{} = workout_session, attrs \\ %{}) do
    WorkoutSession.changeset(workout_session, attrs)
  end

  @doc """
  Returns the list of exercise_logs.

  ## Examples

      iex> list_exercise_logs()
      [%ExerciseLog{}, ...]

  """
  def list_exercise_logs do
    Repo.all(from log in ExerciseLog, order_by: [asc: log.inserted_at])
  end

  def list_exercise_logs_for_session(workout_session_id) do
    Repo.all(
      from log in ExerciseLog,
        where: log.workout_session_id == ^workout_session_id,
        order_by: [asc: log.set_number, asc: log.inserted_at]
    )
  end

  @doc """
  Gets a single exercise_log.

  Raises `Ecto.NoResultsError` if the Exercise log does not exist.

  ## Examples

      iex> get_exercise_log!(123)
      %ExerciseLog{}

      iex> get_exercise_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_exercise_log!(id), do: Repo.get!(ExerciseLog, id)

  @doc """
  Creates a exercise_log.

  ## Examples

      iex> create_exercise_log(%{field: value})
      {:ok, %ExerciseLog{}}

      iex> create_exercise_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_exercise_log(attrs \\ %{}) do
    %ExerciseLog{}
    |> ExerciseLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a exercise_log.

  ## Examples

      iex> update_exercise_log(exercise_log, %{field: new_value})
      {:ok, %ExerciseLog{}}

      iex> update_exercise_log(exercise_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_exercise_log(%ExerciseLog{} = exercise_log, attrs) do
    exercise_log
    |> ExerciseLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a exercise_log.

  ## Examples

      iex> delete_exercise_log(exercise_log)
      {:ok, %ExerciseLog{}}

      iex> delete_exercise_log(exercise_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_exercise_log(%ExerciseLog{} = exercise_log) do
    Repo.delete(exercise_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking exercise_log changes.

  ## Examples

      iex> change_exercise_log(exercise_log)
      %Ecto.Changeset{data: %ExerciseLog{}}

  """
  def change_exercise_log(%ExerciseLog{} = exercise_log, attrs \\ %{}) do
    ExerciseLog.changeset(exercise_log, attrs)
  end

  defp next_set_number(workout_session_id, exercise_id) do
    Repo.one(
      from log in ExerciseLog,
        where: log.workout_session_id == ^workout_session_id and log.exercise_id == ^exercise_id,
        select: max(log.set_number)
    )
    |> case do
      nil -> 1
      set_number -> set_number + 1
    end
  end

  defp workout_session_for_user_query(session_id, user_id) do
    from session in WorkoutSession,
      where: session.id == ^session_id and session.user_id == ^user_id
  end

  defp preload_workout_session(%WorkoutSession{} = session) do
    exercise_query = from exercise in Exercise, order_by: [asc: exercise.position]

    session =
      Repo.preload(session,
        workout_day: [:program, exercises: exercise_query],
        exercise_logs: [:exercise]
      )

    update_in(
      session.workout_day,
      &apply_progression_recommendations_to_workout_day(session.user_id, &1)
    )
  end

  defp preload_workout_day_exercises(
         %WorkoutDay{exercises: %Ecto.Association.NotLoaded{}} = workout_day
       ) do
    exercise_query = from exercise in Exercise, order_by: [asc: exercise.position]
    Repo.preload(workout_day, exercises: exercise_query)
  end

  defp preload_workout_day_exercises(%WorkoutDay{} = workout_day), do: workout_day

  defp latest_completed_logs_by_exercise_name(user_id, normalized_names) do
    Repo.all(
      from log in ExerciseLog,
        join: session in assoc(log, :workout_session),
        join: exercise in assoc(log, :exercise),
        where:
          session.user_id == ^user_id and session.status == "completed" and
            not is_nil(log.weight_kg),
        order_by: [desc: session.completed_at, desc: log.inserted_at],
        select: %{
          exercise_name: exercise.name,
          weight_kg: log.weight_kg
        }
    )
    |> Enum.reduce(%{}, fn log, acc ->
      normalized_name = normalize_exercise_name(log.exercise_name)

      cond do
        is_nil(normalized_name) ->
          acc

        normalized_name not in normalized_names ->
          acc

        Map.has_key?(acc, normalized_name) ->
          acc

        true ->
          Map.put(acc, normalized_name, log)
      end
    end)
  end

  defp apply_progression_to_exercise(exercise, nil) do
    %{exercise | recommended_weight_kg: exercise.weight_kg}
  end

  defp apply_progression_to_exercise(exercise, %{weight_kg: last_logged_weight_kg}) do
    recommended_weight_kg =
      [exercise.weight_kg, last_logged_weight_kg]
      |> Enum.reject(&is_nil/1)
      |> Enum.max(fn -> last_logged_weight_kg end)
      |> Kernel.+(@progression_increment_kg)
      |> round_weight()

    %{
      exercise
      | last_logged_weight_kg: last_logged_weight_kg,
        recommended_weight_kg: recommended_weight_kg,
        progression_hint:
          "Last logged #{format_weight(last_logged_weight_kg)} kg. Suggested next load #{format_weight(recommended_weight_kg)} kg."
    }
  end

  defp normalize_exercise_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_exercise_name(_name), do: nil

  defp round_weight(weight) when is_number(weight), do: Float.round(weight * 2, 0) / 2

  defp format_weight(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)
  defp format_weight(value), do: to_string(value)

  defp maybe_put_duration(attrs, nil), do: attrs

  defp maybe_put_duration(attrs, duration_seconds),
    do: Map.put(attrs, :duration_seconds, duration_seconds)

  defp normalize_param_keys(attrs, extras) do
    if Enum.all?(Map.keys(attrs), &is_binary/1) do
      Map.merge(attrs, Map.new(extras, fn {key, value} -> {Atom.to_string(key), value} end))
    else
      Map.merge(attrs, extras)
    end
  end

  defp log_payload(log) do
    %{
      duration_seconds: log.duration_seconds,
      id: log.id,
      inserted_at: log.inserted_at,
      is_personal_record: log.is_personal_record,
      reps_completed: log.reps_completed,
      rpe: log.rpe,
      set_number: log.set_number,
      weight_kg: log.weight_kg
    }
  end
end
