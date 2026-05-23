defmodule GymBro.Programs do
  @moduledoc """
  The Programs context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset, only: [traverse_errors: 2]
  require Logger
  alias Ecto.Multi
  alias GymBro.Repo

  alias GymBro.AI.PlanGenerator
  alias GymBro.Programs.{Exercise, Program, WorkoutDay}
  alias GymBro.Profiles
  alias GymBro.Profiles.UserProfile
  alias GymBro.Training.WorkoutSession

  @doc """
  Returns the list of programs.

  ## Examples

      iex> list_programs()
      [%Program{}, ...]

  """
  def list_programs do
    Repo.all(from program in Program, order_by: [asc: program.inserted_at])
  end

  def list_programs_for_user(user_id) do
    Repo.all(
      from program in Program,
        where: program.user_id == ^user_id,
        order_by: [asc: program.inserted_at]
    )
  end

  def latest_program_for_user(user_id) do
    Repo.one(
      from program in Program,
        where: program.user_id == ^user_id,
        order_by: [desc: program.inserted_at],
        limit: 1
    )
  end

  def get_active_program_for_user(user_id) do
    Repo.one(
      from program in Program,
        where: program.user_id == ^user_id and program.status == "active",
        order_by: [asc: program.inserted_at],
        limit: 1
    )
  end

  def regenerate_ai_program_for_user(user_id, created_by_id, plan_notes \\ nil, overrides \\ %{}) do
    overrides = Map.new(overrides)
    generation_overrides = Map.take(overrides, [:block_weeks])
    program_overrides = Map.drop(overrides, [:block_weeks])

    with %UserProfile{} = profile <- Profiles.get_user_profile_by_user(user_id),
         {:ok, parsed_plan} <- PlanGenerator.generate(profile, plan_notes, generation_overrides) do
      replace_active_program_with_ai_plan(
        user_id,
        created_by_id,
        parsed_plan,
        program_overrides
        |> Map.new()
        |> Map.put_new(:source, "ai")
        |> Map.put_new(:status, "active")
      )
    else
      nil -> {:error, :missing_profile}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_workout_days_for_user(user_id) do
    exercise_query = from exercise in Exercise, order_by: [asc: exercise.position]

    Repo.all(
      from workout_day in WorkoutDay,
        join: program in assoc(workout_day, :program),
        where: program.user_id == ^user_id and program.status == "active",
        order_by: [asc: workout_day.week_number, asc: workout_day.day_number],
        preload: [program: program, exercises: ^exercise_query]
    )
  end

  def get_workout_day_for_user!(user_id, workout_day_id) do
    exercise_query = from exercise in Exercise, order_by: [asc: exercise.position]

    Repo.one!(
      from workout_day in WorkoutDay,
        join: program in assoc(workout_day, :program),
        where:
          workout_day.id == ^workout_day_id and program.user_id == ^user_id and
            program.status == "active",
        preload: [program: program, exercises: ^exercise_query]
    )
  end

  def get_next_workout_for_user(user_id) do
    case get_active_program_for_user(user_id) do
      nil ->
        nil

      program ->
        program = Repo.preload(program, workout_days: [:exercises])

        completed_workout_day_ids =
          Repo.all(
            from session in WorkoutSession,
              join: workout_day in WorkoutDay,
              on: workout_day.id == session.workout_day_id,
              where:
                session.user_id == ^user_id and
                  session.status == "completed" and
                  workout_day.program_id == ^program.id,
              select: session.workout_day_id,
              distinct: true
          )
          |> MapSet.new()

        ordered_workout_days =
          program.workout_days
          |> Enum.reject(& &1.is_rest_day)
          |> Enum.sort_by(&{&1.week_number, &1.day_number})

        current_or_future_day =
          Enum.find(ordered_workout_days, fn workout_day ->
            workout_day.week_number >= program.current_week and
              not MapSet.member?(completed_workout_day_ids, workout_day.id)
          end)

        fallback_day =
          Enum.find(ordered_workout_days, fn workout_day ->
            not MapSet.member?(completed_workout_day_ids, workout_day.id)
          end) || List.first(ordered_workout_days)

        build_next_workout(program, current_or_future_day || fallback_day)
    end
  end

  @doc """
  Gets a single program.

  Raises `Ecto.NoResultsError` if the Program does not exist.

  ## Examples

      iex> get_program!(123)
      %Program{}

      iex> get_program!(456)
      ** (Ecto.NoResultsError)

  """
  def get_program!(id), do: Repo.get!(Program, id)

  @doc """
  Creates a program.

  ## Examples

      iex> create_program(%{field: value})
      {:ok, %Program{}}

      iex> create_program(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_program(attrs \\ %{}) do
    %Program{}
    |> Program.changeset(attrs)
    |> Repo.insert()
  end

  def import_ai_plan(user_id, created_by_id, parsed_plan, overrides \\ %{})

  def import_ai_plan(
        user_id,
        created_by_id,
        %{program: program_attrs, workout_days: workout_days, raw_plan: raw_plan},
        overrides
      ) do
    attrs =
      program_attrs
      |> Map.merge(%{
        ai_raw_plan: raw_plan,
        created_by_id: created_by_id,
        user_id: user_id
      })
      |> Map.merge(Map.new(overrides))

    Multi.new()
    |> Multi.insert(:program, Program.changeset(%Program{}, attrs))
    |> Multi.run(:workout_days, fn repo, %{program: program} ->
      insert_workout_days(repo, program, workout_days)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{program: program}} ->
        program = Repo.preload(program, workout_days: :exercises)
        log_program_persisted(program, "imported")
        {:ok, program}

      {:error, step, reason, changes_so_far} ->
        log_program_persist_failure("imported", step, reason, changes_so_far)
        {:error, reason}
    end
  end

  def replace_active_program_with_ai_plan(
        user_id,
        created_by_id,
        %{program: program_attrs, workout_days: workout_days, raw_plan: raw_plan},
        overrides \\ %{}
      ) do
    attrs =
      program_attrs
      |> Map.merge(%{
        ai_raw_plan: raw_plan,
        created_by_id: created_by_id,
        user_id: user_id
      })
      |> Map.merge(Map.new(overrides))

    active_program = get_active_program_for_user(user_id)

    Multi.new()
    |> maybe_pause_active_program(active_program)
    |> Multi.insert(:program, Program.changeset(%Program{}, attrs))
    |> Multi.run(:workout_days, fn repo, %{program: program} ->
      insert_workout_days(repo, program, workout_days)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{program: program}} ->
        program = preload_program_structure(program)
        log_program_persisted(program, "replaced_active")
        {:ok, program}

      {:error, step, reason, changes_so_far} ->
        log_program_persist_failure("replaced_active", step, reason, changes_so_far)
        {:error, reason}
    end
  end

  defp log_program_persisted(program, operation) do
    workout_days = List.wrap(program.workout_days)

    exercise_count =
      workout_days
      |> Enum.map(&length(List.wrap(&1.exercises)))
      |> Enum.sum()

    Logger.info(
      "Program persisted operation=#{operation} program_id=#{program.id} user_id=#{program.user_id} status=#{program.status} source=#{program.source} total_weeks=#{program.total_weeks} workout_days=#{length(workout_days)} exercises=#{exercise_count}"
    )
  end

  defp log_program_persist_failure(operation, step, %Ecto.Changeset{} = changeset, changes_so_far) do
    Logger.warning(
      "Program persistence failed operation=#{operation} step=#{step} errors=#{inspect(changeset_errors(changeset))} changes_so_far=#{inspect(Map.keys(changes_so_far))}"
    )
  end

  defp log_program_persist_failure(operation, step, reason, changes_so_far) do
    Logger.warning(
      "Program persistence failed operation=#{operation} step=#{step} reason=#{inspect(reason)} changes_so_far=#{inspect(Map.keys(changes_so_far))}"
    )
  end

  defp changeset_errors(changeset) do
    traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @doc """
  Updates a program.

  ## Examples

      iex> update_program(program, %{field: new_value})
      {:ok, %Program{}}

      iex> update_program(program, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_program(%Program{} = program, attrs) do
    program
    |> Program.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a program.

  ## Examples

      iex> delete_program(program)
      {:ok, %Program{}}

      iex> delete_program(program)
      {:error, %Ecto.Changeset{}}

  """
  def delete_program(%Program{} = program) do
    Repo.delete(program)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking program changes.

  ## Examples

      iex> change_program(program)
      %Ecto.Changeset{data: %Program{}}

  """
  def change_program(%Program{} = program, attrs \\ %{}) do
    Program.changeset(program, attrs)
  end

  @doc """
  Returns the list of workout_days.

  ## Examples

      iex> list_workout_days()
      [%WorkoutDay{}, ...]

  """
  def list_workout_days do
    Repo.all(
      from workout_day in WorkoutDay,
        order_by: [asc: workout_day.week_number, asc: workout_day.day_number]
    )
  end

  def list_workout_days_for_program(program_id) do
    Repo.all(
      from workout_day in WorkoutDay,
        where: workout_day.program_id == ^program_id,
        order_by: [asc: workout_day.week_number, asc: workout_day.day_number]
    )
  end

  @doc """
  Gets a single workout_day.

  Raises `Ecto.NoResultsError` if the Workout day does not exist.

  ## Examples

      iex> get_workout_day!(123)
      %WorkoutDay{}

      iex> get_workout_day!(456)
      ** (Ecto.NoResultsError)

  """
  def get_workout_day!(id), do: Repo.get!(WorkoutDay, id)

  @doc """
  Creates a workout_day.

  ## Examples

      iex> create_workout_day(%{field: value})
      {:ok, %WorkoutDay{}}

      iex> create_workout_day(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_workout_day(attrs \\ %{}) do
    %WorkoutDay{}
    |> WorkoutDay.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a workout_day.

  ## Examples

      iex> update_workout_day(workout_day, %{field: new_value})
      {:ok, %WorkoutDay{}}

      iex> update_workout_day(workout_day, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_workout_day(%WorkoutDay{} = workout_day, attrs) do
    workout_day
    |> WorkoutDay.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a workout_day.

  ## Examples

      iex> delete_workout_day(workout_day)
      {:ok, %WorkoutDay{}}

      iex> delete_workout_day(workout_day)
      {:error, %Ecto.Changeset{}}

  """
  def delete_workout_day(%WorkoutDay{} = workout_day) do
    Repo.delete(workout_day)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking workout_day changes.

  ## Examples

      iex> change_workout_day(workout_day)
      %Ecto.Changeset{data: %WorkoutDay{}}

  """
  def change_workout_day(%WorkoutDay{} = workout_day, attrs \\ %{}) do
    WorkoutDay.changeset(workout_day, attrs)
  end

  @doc """
  Returns the list of exercises.

  ## Examples

      iex> list_exercises()
      [%Exercise{}, ...]

  """
  def list_exercises do
    Repo.all(from exercise in Exercise, order_by: [asc: exercise.position])
  end

  def list_exercises_for_workout_day(workout_day_id) do
    Repo.all(
      from exercise in Exercise,
        where: exercise.workout_day_id == ^workout_day_id,
        order_by: [asc: exercise.position]
    )
  end

  def next_exercise_position(workout_day_id) do
    Repo.one(
      from exercise in Exercise,
        where: exercise.workout_day_id == ^workout_day_id,
        select: max(exercise.position)
    )
    |> case do
      nil -> 1
      position -> position + 1
    end
  end

  @doc """
  Gets a single exercise.

  Raises `Ecto.NoResultsError` if the Exercise does not exist.

  ## Examples

      iex> get_exercise!(123)
      %Exercise{}

      iex> get_exercise!(456)
      ** (Ecto.NoResultsError)

  """
  def get_exercise!(id), do: Repo.get!(Exercise, id)

  @doc """
  Creates a exercise.

  ## Examples

      iex> create_exercise(%{field: value})
      {:ok, %Exercise{}}

      iex> create_exercise(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_exercise(attrs \\ %{}) do
    %Exercise{}
    |> Exercise.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a exercise.

  ## Examples

      iex> update_exercise(exercise, %{field: new_value})
      {:ok, %Exercise{}}

      iex> update_exercise(exercise, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_exercise(%Exercise{} = exercise, attrs) do
    exercise
    |> Exercise.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a exercise.

  ## Examples

      iex> delete_exercise(exercise)
      {:ok, %Exercise{}}

      iex> delete_exercise(exercise)
      {:error, %Ecto.Changeset{}}

  """
  def delete_exercise(%Exercise{} = exercise) do
    Repo.delete(exercise)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking exercise changes.

  ## Examples

      iex> change_exercise(exercise)
      %Ecto.Changeset{data: %Exercise{}}

  """
  def change_exercise(%Exercise{} = exercise, attrs \\ %{}) do
    Exercise.changeset(exercise, attrs)
  end

  def preload_program_structure(%Program{} = program) do
    exercise_query = from exercise in Exercise, order_by: [asc: exercise.position]

    workout_day_query =
      from workout_day in WorkoutDay,
        order_by: [asc: workout_day.week_number, asc: workout_day.day_number],
        preload: [exercises: ^exercise_query]

    Repo.preload(program, workout_days: workout_day_query)
  end

  def resequence_exercises(workout_day_id) do
    Repo.transaction(fn ->
      workout_day_id
      |> list_exercises_for_workout_day()
      |> Enum.with_index(1)
      |> Enum.each(fn {exercise, position} ->
        if exercise.position != position do
          from(existing in Exercise, where: existing.id == ^exercise.id)
          |> Repo.update_all(set: [position: position])
        end
      end)
    end)

    {:ok, list_exercises_for_workout_day(workout_day_id)}
  end

  defp maybe_pause_active_program(multi, nil), do: multi

  defp maybe_pause_active_program(multi, %Program{} = active_program) do
    Multi.update(multi, :previous_program, Program.changeset(active_program, %{status: "paused"}))
  end

  defp insert_workout_days(repo, program, workout_days) do
    workout_days
    |> Enum.reduce_while({:ok, []}, fn workout_day_attrs, {:ok, acc_days} ->
      attrs =
        workout_day_attrs
        |> Map.drop([:exercises])
        |> Map.put(:program_id, program.id)

      case repo.insert(WorkoutDay.changeset(%WorkoutDay{}, attrs)) do
        {:ok, workout_day} ->
          case insert_exercises(repo, workout_day, Map.get(workout_day_attrs, :exercises, [])) do
            {:ok, exercises} ->
              {:cont, {:ok, [%{workout_day | exercises: exercises} | acc_days]}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        {:error, changeset} ->
          {:halt, {:error, changeset}}
      end
    end)
  end

  defp insert_exercises(repo, workout_day, exercises) do
    exercises
    |> Enum.reduce_while({:ok, []}, fn exercise_attrs, {:ok, acc_exercises} ->
      attrs = Map.put(exercise_attrs, :workout_day_id, workout_day.id)

      case repo.insert(Exercise.changeset(%Exercise{}, attrs)) do
        {:ok, exercise} ->
          {:cont, {:ok, [exercise | acc_exercises]}}

        {:error, changeset} ->
          {:halt, {:error, changeset}}
      end
    end)
    |> case do
      {:ok, inserted_exercises} ->
        {:ok, Enum.sort_by(inserted_exercises, & &1.position)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_next_workout(_program, nil), do: nil

  defp build_next_workout(program, workout_day) do
    %{
      program_name: program.name,
      phase_name: program.phase_name,
      week_number: workout_day.week_number,
      day_number: workout_day.day_number,
      day_label: workout_day.day_label,
      workout_type: workout_day.workout_type,
      estimated_duration_min: workout_day.estimated_duration_min,
      muscle_groups: workout_day.muscle_groups || [],
      trainer_notes: workout_day.trainer_notes,
      exercises: Enum.sort_by(workout_day.exercises, & &1.position),
      exercise_count: length(workout_day.exercises)
    }
  end
end
