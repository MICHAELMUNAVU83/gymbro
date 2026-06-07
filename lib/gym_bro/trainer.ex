defmodule GymBro.Trainer do
  @moduledoc """
  The Trainer context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias GymBro.Repo

  alias GymBro.Accounts.UserNotifier
  alias GymBro.Accounts.User
  alias GymBro.BodyStats
  alias GymBro.BodyStats.CheckinImage
  alias GymBro.Profiles
  alias GymBro.Programs
  alias GymBro.Programs.{Exercise, Program, WorkoutDay}
  alias GymBro.Profiles.UserProfile
  alias GymBro.Trainer.TrainerClient
  alias GymBro.Training
  alias GymBro.Training.WorkoutSession

  @client_invitation_lifetime_seconds 48 * 60 * 60
  @exercise_fields ~w(
    duration_seconds
    is_timed
    name
    notes
    position
    reps
    rest_seconds
    sets
    trainer_notes
    visual_guide
    weight_kg
    workout_day_id
  )a

  @doc """
  Returns the list of trainer_clients.

  ## Examples

      iex> list_trainer_clients()
      [%TrainerClient{}, ...]

  """
  def list_trainer_clients do
    Repo.all(from relationship in TrainerClient, order_by: [asc: relationship.inserted_at])
  end

  def list_trainer_clients(trainer_id) do
    Repo.all(
      from relationship in TrainerClient,
        where: relationship.trainer_id == ^trainer_id,
        order_by: [asc: relationship.inserted_at]
    )
  end

  def list_managed_clients(trainer_id, search \\ nil) do
    trainer_id
    |> managed_clients_query()
    |> Repo.all()
    |> Enum.map(&build_client_list_item/1)
    |> filter_managed_clients(search)
  end

  def get_managed_client_detail(trainer_id, client_id) do
    relationship =
      Repo.one(
        from relationship in TrainerClient,
          where: relationship.trainer_id == ^trainer_id and relationship.client_id == ^client_id,
          preload: [client: ^client_profile_preload_query()]
      )

    case relationship do
      nil ->
        {:error, :not_found}

      %TrainerClient{} = relationship ->
        client = relationship.client
        profile = client.user_profile
        weight_logs = BodyStats.list_body_weight_logs_for_user_chronological(client.id)
        personal_records = BodyStats.list_personal_records_for_user(client.id)

        {:ok,
         %{
           client: client,
           relationship: relationship,
           profile: profile,
           weight_logs: weight_logs,
           latest_weight: BodyStats.latest_body_weight_log(client.id),
           checkin_images: visible_images_for_user(client.id, "checkin"),
           progress_images: visible_images_for_user(client.id, "progress"),
           personal_records: personal_records,
           program: active_or_latest_program(client.id),
           overrides_by_exercise_id: overrides_by_exercise_id(trainer_id, client.id)
         }}
    end
  end

  @doc """
  Verifies that a trainer has an active relationship with a client before
  accessing client-specific data.
  """
  def verify_client_access(trainer_id, client_id) do
    case Repo.get_by(TrainerClient,
           trainer_id: trainer_id,
           client_id: client_id,
           status: "active"
         ) do
      nil -> {:error, :unauthorized}
      _relationship -> :ok
    end
  end

  def get_trainer_client(trainer_id, client_id) do
    Repo.get_by(TrainerClient, trainer_id: trainer_id, client_id: client_id)
  end

  def get_or_start_client_workout_session(trainer_id, client_id, workout_day_id) do
    with :ok <- verify_client_access(trainer_id, client_id),
         {:ok, workout_day} <- fetch_client_workout_day(client_id, workout_day_id) do
      Training.get_or_start_workout_session(client_id, workout_day.id)
    end
  end

  def log_client_exercise_set(trainer_id, client_id, session_id, exercise_id, attrs \\ %{}) do
    with :ok <- verify_client_access(trainer_id, client_id),
         {:ok, session} <- fetch_client_workout_session(client_id, session_id),
         {:ok, exercise} <- fetch_client_exercise(client_id, exercise_id) do
      Training.log_exercise_set(session, exercise, attrs)
    end
  end

  def complete_client_workout_session(trainer_id, client_id, session_id) do
    with :ok <- verify_client_access(trainer_id, client_id),
         {:ok, session} <- fetch_client_workout_session(client_id, session_id) do
      Training.complete_workout_session(session)
    end
  end

  def add_exercise_to_client_day(trainer_id, client_id, workout_day_id, attrs) do
    with :ok <- verify_client_access(trainer_id, client_id),
         {:ok, workout_day} <- fetch_client_workout_day(client_id, workout_day_id) do
      attrs =
        attrs
        |> normalize_exercise_attrs()
        |> Map.put(:workout_day_id, workout_day.id)
        |> Map.put_new(:position, Programs.next_exercise_position(workout_day.id))

      Programs.create_exercise(attrs)
    end
  end

  def update_client_exercise(trainer_id, client_id, exercise_id, attrs) do
    attrs = normalize_exercise_attrs(attrs)

    with :ok <- verify_client_access(trainer_id, client_id),
         {:ok, exercise} <- fetch_client_exercise(client_id, exercise_id),
         {:ok, exercise} <- Programs.update_exercise(exercise, attrs) do
      case maybe_upsert_exercise_override(trainer_id, client_id, exercise, attrs) do
        {:ok, _override} -> {:ok, exercise}
        :skip -> {:ok, exercise}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  def remove_client_exercise(trainer_id, client_id, exercise_id) do
    with :ok <- verify_client_access(trainer_id, client_id),
         {:ok, exercise} <- fetch_client_exercise(client_id, exercise_id),
         {:ok, _exercise} <- Programs.delete_exercise(exercise) do
      Programs.resequence_exercises(exercise.workout_day_id)
      :ok
    end
  end

  @doc """
  Returns the client's profile changeset for trainer-facing config forms.
  """
  def change_client_profile(%UserProfile{} = profile, attrs \\ %{}) do
    Profiles.change_user_profile(profile, attrs)
  end

  @doc """
  Updates a managed client's profile (weight, goals, schedule, etc.) after
  verifying the trainer has access to the client.
  """
  def update_client_profile(trainer_id, client_id, attrs) do
    with :ok <- verify_client_access(trainer_id, client_id),
         %UserProfile{} = profile <- Profiles.get_user_profile_by_user(client_id) do
      Profiles.update_user_profile(profile, attrs)
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, :missing_profile}
    end
  end

  @doc """
  Saves the client's profile and regenerates their AI program in one step.
  """
  def reconfigure_and_regenerate_client_program(
        trainer_id,
        client_id,
        profile_attrs,
        trainer_notes \\ nil
      ) do
    with {:ok, profile} <- update_client_profile(trainer_id, client_id, profile_attrs) do
      overrides = %{block_weeks: profile.preferred_block_weeks}

      case regenerate_client_program(trainer_id, client_id, trainer_notes, overrides) do
        {:ok, program} -> {:ok, program}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def regenerate_client_program(trainer_id, client_id, trainer_notes \\ nil, overrides \\ %{}) do
    with :ok <- verify_client_access(trainer_id, client_id) do
      Programs.regenerate_ai_program_for_user(
        client_id,
        trainer_id,
        trainer_notes,
        overrides
        |> Map.new()
        |> Map.put(:source, "ai_trainer_edited")
        |> Map.put(:status, "active")
      )
    end
  end

  @doc """
  Gets a single trainer_client.

  Raises `Ecto.NoResultsError` if the Trainer client does not exist.

  ## Examples

      iex> get_trainer_client!(123)
      %TrainerClient{}

      iex> get_trainer_client!(456)
      ** (Ecto.NoResultsError)

  """
  def get_trainer_client!(id), do: Repo.get!(TrainerClient, id)

  @doc """
  Creates a trainer_client.

  ## Examples

      iex> create_trainer_client(%{field: value})
      {:ok, %TrainerClient{}}

      iex> create_trainer_client(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_trainer_client(attrs \\ %{}) do
    %TrainerClient{}
    |> TrainerClient.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trainer_client.

  ## Examples

      iex> update_trainer_client(trainer_client, %{field: new_value})
      {:ok, %TrainerClient{}}

      iex> update_trainer_client(trainer_client, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_trainer_client(%TrainerClient{} = trainer_client, attrs) do
    trainer_client
    |> TrainerClient.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trainer_client.

  ## Examples

      iex> delete_trainer_client(trainer_client)
      {:ok, %TrainerClient{}}

      iex> delete_trainer_client(trainer_client)
      {:error, %Ecto.Changeset{}}

  """
  def delete_trainer_client(%TrainerClient{} = trainer_client) do
    Repo.delete(trainer_client)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trainer_client changes.

  ## Examples

      iex> change_trainer_client(trainer_client)
      %Ecto.Changeset{data: %TrainerClient{}}

  """
  def change_trainer_client(%TrainerClient{} = trainer_client, attrs \\ %{}) do
    TrainerClient.changeset(trainer_client, attrs)
  end

  alias GymBro.Trainer.ClientInvitation

  @doc """
  Returns the list of client_invitations.

  ## Examples

      iex> list_client_invitations()
      [%ClientInvitation{}, ...]

  """
  def list_client_invitations do
    Repo.all(from invitation in ClientInvitation, order_by: [desc: invitation.inserted_at])
  end

  def list_client_invitations(trainer_id) do
    Repo.all(
      from invitation in ClientInvitation,
        where: invitation.trainer_id == ^trainer_id,
        order_by: [desc: invitation.inserted_at]
    )
  end

  def get_client_invitation_by_token(token) do
    Repo.get_by(ClientInvitation, token: token)
  end

  @doc """
  Gets a single client_invitation.

  Raises `Ecto.NoResultsError` if the Client invitation does not exist.

  ## Examples

      iex> get_client_invitation!(123)
      %ClientInvitation{}

      iex> get_client_invitation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_client_invitation!(id), do: Repo.get!(ClientInvitation, id)

  @doc """
  Creates a client_invitation.

  ## Examples

      iex> create_client_invitation(%{field: value})
      {:ok, %ClientInvitation{}}

      iex> create_client_invitation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_client_invitation(attrs \\ %{}) do
    %ClientInvitation{}
    |> ClientInvitation.changeset(attrs)
    |> Repo.insert()
  end

  def deliver_client_invitation(%User{} = trainer, attrs, accept_url_fun)
      when is_function(accept_url_fun, 1) do
    attrs = normalize_client_invitation_attrs(attrs)
    email = invitation_email_from_attrs(attrs)

    with {:ok, invitation} <- issue_client_invitation(trainer.id, email, attrs),
         {:ok, _email} <-
           UserNotifier.deliver_client_invitation(
             trainer,
             invitation,
             accept_url_fun.(invitation.token)
           ) do
      {:ok, invitation}
    end
  end

  def issue_client_invitation(trainer_id, email, attrs \\ %{}) do
    email = normalize_email(email)
    attrs = normalize_client_invitation_attrs(attrs)

    attrs =
      %{
        trainer_id: trainer_id,
        email: email,
        token: Ecto.UUID.generate(),
        status: "pending",
        expires_at:
          DateTime.add(DateTime.utc_now(), @client_invitation_lifetime_seconds, :second)
          |> DateTime.truncate(:second)
      }
      |> Map.merge(attrs)

    create_client_invitation(attrs)
  end

  def fetch_joinable_client_invitation(token) when is_binary(token) do
    token
    |> invitation_query()
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      %ClientInvitation{} = invitation ->
        validate_joinable_invitation(invitation)
    end
  end

  def accept_client_invitation(token, %User{} = user) when is_binary(token) do
    with {:ok, invitation} <- fetch_joinable_client_invitation(token),
         :ok <- ensure_invitation_email_matches_user(invitation, user) do
      Multi.new()
      |> Multi.run(:trainer_client, fn repo, _changes ->
        ensure_trainer_client_link(repo, invitation, user)
      end)
      |> Multi.update(
        :client_invitation,
        ClientInvitation.changeset(invitation, %{status: "accepted"})
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{trainer_client: trainer_client}} -> {:ok, trainer_client}
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    end
  end

  def register_invited_client(attrs, token) when is_binary(token) do
    with {:ok, invitation} <- fetch_joinable_client_invitation(token) do
      user_attrs =
        attrs
        |> stringify_keys()
        |> Map.put("email", invitation.email)
        |> Map.put("role", "athlete")

      Multi.new()
      |> Multi.insert(:user, User.registration_changeset(%User{}, user_attrs))
      |> Multi.run(:trainer_client, fn repo, %{user: user} ->
        ensure_trainer_client_link(repo, invitation, user)
      end)
      |> Multi.update(
        :client_invitation,
        ClientInvitation.changeset(invitation, %{status: "accepted"})
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{user: user}} ->
          {:ok, user}

        {:error, :user, changeset, _changes} ->
          {:error, changeset}

        {:error, _step, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Updates a client_invitation.

  ## Examples

      iex> update_client_invitation(client_invitation, %{field: new_value})
      {:ok, %ClientInvitation{}}

      iex> update_client_invitation(client_invitation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_client_invitation(%ClientInvitation{} = client_invitation, attrs) do
    client_invitation
    |> ClientInvitation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a client_invitation.

  ## Examples

      iex> delete_client_invitation(client_invitation)
      {:ok, %ClientInvitation{}}

      iex> delete_client_invitation(client_invitation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_client_invitation(%ClientInvitation{} = client_invitation) do
    Repo.delete(client_invitation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking client_invitation changes.

  ## Examples

      iex> change_client_invitation(client_invitation)
      %Ecto.Changeset{data: %ClientInvitation{}}

  """
  def change_client_invitation(%ClientInvitation{} = client_invitation, attrs \\ %{}) do
    ClientInvitation.changeset(client_invitation, attrs)
  end

  alias GymBro.Trainer.TrainerExerciseOverride

  @doc """
  Returns the list of trainer_exercise_overrides.

  ## Examples

      iex> list_trainer_exercise_overrides()
      [%TrainerExerciseOverride{}, ...]

  """
  def list_trainer_exercise_overrides do
    Repo.all(from override in TrainerExerciseOverride, order_by: [desc: override.inserted_at])
  end

  def list_trainer_exercise_overrides_for_client(client_id, trainer_id \\ nil) do
    query =
      from override in TrainerExerciseOverride,
        where: override.client_id == ^client_id and override.active == true,
        order_by: [desc: override.inserted_at]

    query =
      if trainer_id do
        from override in query, where: override.trainer_id == ^trainer_id
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets a single trainer_exercise_override.

  Raises `Ecto.NoResultsError` if the Trainer exercise override does not exist.

  ## Examples

      iex> get_trainer_exercise_override!(123)
      %TrainerExerciseOverride{}

      iex> get_trainer_exercise_override!(456)
      ** (Ecto.NoResultsError)

  """
  def get_trainer_exercise_override!(id), do: Repo.get!(TrainerExerciseOverride, id)

  @doc """
  Creates a trainer_exercise_override.

  ## Examples

      iex> create_trainer_exercise_override(%{field: value})
      {:ok, %TrainerExerciseOverride{}}

      iex> create_trainer_exercise_override(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_trainer_exercise_override(attrs \\ %{}) do
    %TrainerExerciseOverride{}
    |> TrainerExerciseOverride.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trainer_exercise_override.

  ## Examples

      iex> update_trainer_exercise_override(trainer_exercise_override, %{field: new_value})
      {:ok, %TrainerExerciseOverride{}}

      iex> update_trainer_exercise_override(trainer_exercise_override, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_trainer_exercise_override(
        %TrainerExerciseOverride{} = trainer_exercise_override,
        attrs
      ) do
    trainer_exercise_override
    |> TrainerExerciseOverride.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trainer_exercise_override.

  ## Examples

      iex> delete_trainer_exercise_override(trainer_exercise_override)
      {:ok, %TrainerExerciseOverride{}}

      iex> delete_trainer_exercise_override(trainer_exercise_override)
      {:error, %Ecto.Changeset{}}

  """
  def delete_trainer_exercise_override(%TrainerExerciseOverride{} = trainer_exercise_override) do
    Repo.delete(trainer_exercise_override)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trainer_exercise_override changes.

  ## Examples

      iex> change_trainer_exercise_override(trainer_exercise_override)
      %Ecto.Changeset{data: %TrainerExerciseOverride{}}

  """
  def change_trainer_exercise_override(
        %TrainerExerciseOverride{} = trainer_exercise_override,
        attrs \\ %{}
      ) do
    TrainerExerciseOverride.changeset(trainer_exercise_override, attrs)
  end

  defp managed_clients_query(trainer_id) do
    from relationship in TrainerClient,
      join: client in assoc(relationship, :client),
      left_join: profile in UserProfile,
      on: profile.user_id == client.id,
      where: relationship.trainer_id == ^trainer_id,
      order_by: [asc: relationship.status, asc: client.email],
      select: %{
        id: client.id,
        email: client.email,
        joined_at: relationship.joined_at,
        notes: relationship.notes,
        status: relationship.status,
        goal: profile.goal,
        days_per_week: profile.days_per_week,
        fitness_level: profile.fitness_level
      }
  end

  defp build_client_list_item(client) do
    Map.merge(client, %{
      display_name: display_name(client.email),
      goal_label: format_goal(client.goal),
      schedule_label: format_schedule(client.days_per_week),
      fitness_level_label: format_fitness_level(client.fitness_level)
    })
  end

  defp filter_managed_clients(clients, nil), do: clients
  defp filter_managed_clients(clients, ""), do: clients

  defp filter_managed_clients(clients, search) do
    normalized_search = normalize_search(search)

    Enum.filter(clients, fn client ->
      normalized_display_name = normalize_search(client.display_name)
      normalized_email = normalize_search(client.email)

      String.contains?(normalized_display_name, normalized_search) or
        String.contains?(normalized_email, normalized_search)
    end)
  end

  defp client_profile_preload_query do
    from client in User,
      preload: [:user_profile]
  end

  defp visible_images_for_user(user_id, image_type) do
    Repo.all(
      from image in CheckinImage,
        where:
          image.user_id == ^user_id and image.image_type == ^image_type and
            image.visible_to_trainer == true,
        order_by: [desc: image.logged_at, desc: image.inserted_at]
    )
  end

  defp active_or_latest_program(client_id) do
    client_id
    |> Programs.get_active_program_for_user()
    |> case do
      nil -> Programs.latest_program_for_user(client_id)
      %Program{} = program -> program
    end
    |> case do
      nil -> nil
      %Program{} = program -> Programs.preload_program_structure(program)
    end
  end

  defp overrides_by_exercise_id(trainer_id, client_id) do
    client_id
    |> list_trainer_exercise_overrides_for_client(trainer_id)
    |> Map.new(&{&1.exercise_id, &1})
  end

  defp fetch_client_workout_day(client_id, workout_day_id) do
    case Repo.one(
           from workout_day in WorkoutDay,
             join: program in assoc(workout_day, :program),
             where: workout_day.id == ^workout_day_id and program.user_id == ^client_id,
             preload: [program: program]
         ) do
      nil -> {:error, :not_found}
      %WorkoutDay{} = workout_day -> {:ok, workout_day}
    end
  end

  defp fetch_client_exercise(client_id, exercise_id) do
    case Repo.one(
           from exercise in Exercise,
             join: workout_day in assoc(exercise, :workout_day),
             join: program in assoc(workout_day, :program),
             where: exercise.id == ^exercise_id and program.user_id == ^client_id
         ) do
      nil -> {:error, :not_found}
      %Exercise{} = exercise -> {:ok, exercise}
    end
  end

  defp fetch_client_workout_session(client_id, session_id) do
    case Repo.get_by(WorkoutSession, id: session_id, user_id: client_id) do
      nil -> {:error, :not_found}
      %WorkoutSession{} = session -> {:ok, session}
    end
  end

  defp maybe_upsert_exercise_override(trainer_id, client_id, %Exercise{} = exercise, attrs) do
    override_attrs =
      attrs
      |> Map.take([:sets, :reps, :weight_kg, :notes])
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()

    if map_size(override_attrs) == 0 do
      :skip
    else
      override =
        Repo.get_by(TrainerExerciseOverride,
          trainer_id: trainer_id,
          client_id: client_id,
          exercise_id: exercise.id
        )

      override_attrs =
        Map.merge(override_attrs, %{
          active: true,
          client_id: client_id,
          exercise_id: exercise.id,
          trainer_id: trainer_id
        })

      case override do
        nil ->
          create_trainer_exercise_override(override_attrs)

        %TrainerExerciseOverride{} = override ->
          update_trainer_exercise_override(override, override_attrs)
      end
    end
  end

  defp normalize_search(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, " ")
    |> String.trim()
  end

  defp normalize_exercise_attrs(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn
      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)

      {key, value}, acc when is_binary(key) ->
        case Enum.find(@exercise_fields, &(Atom.to_string(&1) == key)) do
          nil -> acc
          normalized_key -> Map.put(acc, normalized_key, value)
        end
    end)
  end

  defp display_name(email) do
    email
    |> to_string()
    |> String.split("@")
    |> List.first()
    |> String.replace(~r/[._-]+/u, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_goal(nil), do: "Goal pending"

  defp format_goal(goal) do
    goal
    |> to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_schedule(nil), do: "Schedule pending"
  defp format_schedule(days_per_week), do: "#{days_per_week} training days"

  defp format_fitness_level(nil), do: "Level pending"

  defp format_fitness_level(level) do
    level
    |> to_string()
    |> String.capitalize()
  end

  defp invitation_query(token) do
    from invitation in ClientInvitation,
      where: invitation.token == ^token,
      preload: [:trainer]
  end

  defp validate_joinable_invitation(%ClientInvitation{status: "accepted"}) do
    {:error, :accepted}
  end

  defp validate_joinable_invitation(%ClientInvitation{status: "expired"}) do
    {:error, :expired}
  end

  defp validate_joinable_invitation(%ClientInvitation{} = invitation) do
    if invitation_expired?(invitation) do
      expire_client_invitation(invitation)
      {:error, :expired}
    else
      {:ok, invitation}
    end
  end

  defp invitation_expired?(%ClientInvitation{expires_at: nil}), do: false

  defp invitation_expired?(%ClientInvitation{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  defp expire_client_invitation(invitation) do
    invitation
    |> ClientInvitation.changeset(%{status: "expired"})
    |> Repo.update()
  end

  defp ensure_invitation_email_matches_user(invitation, user) do
    if normalize_email(invitation.email) == normalize_email(user.email) do
      :ok
    else
      {:error, :email_mismatch}
    end
  end

  defp ensure_trainer_client_link(repo, invitation, user) do
    case repo.get_by(TrainerClient, trainer_id: invitation.trainer_id, client_id: user.id) do
      nil ->
        %TrainerClient{}
        |> TrainerClient.changeset(%{
          trainer_id: invitation.trainer_id,
          client_id: user.id,
          joined_at: Date.utc_today(),
          status: "active"
        })
        |> repo.insert()

      trainer_client ->
        {:ok, trainer_client}
    end
  end

  defp normalize_client_invitation_attrs(attrs) do
    attrs = Enum.into(attrs, %{})

    %{
      trainer_id: Map.get(attrs, :trainer_id, Map.get(attrs, "trainer_id")),
      email: invitation_email_from_attrs(attrs),
      token: Map.get(attrs, :token, Map.get(attrs, "token")),
      status: Map.get(attrs, :status, Map.get(attrs, "status")),
      expires_at: Map.get(attrs, :expires_at, Map.get(attrs, "expires_at"))
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp invitation_email_from_attrs(attrs) do
    attrs
    |> Map.get(:email, Map.get(attrs, "email"))
    |> normalize_email()
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) do
    email
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end

  defp stringify_keys(attrs) do
    attrs
    |> Enum.into(%{})
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
  end
end
