defmodule GymBro.Profiles do
  @moduledoc """
  The Profiles context.
  """

  import Ecto.Query, warn: false
  alias GymBro.Repo

  alias GymBro.Profiles.UserProfile

  @doc """
  Returns the list of user_profiles.

  ## Examples

      iex> list_user_profiles()
      [%UserProfile{}, ...]

  """
  def list_user_profiles do
    Repo.all(from profile in UserProfile, order_by: [asc: profile.inserted_at])
  end

  @doc """
  Gets a single user_profile.

  Raises `Ecto.NoResultsError` if the User profile does not exist.

  ## Examples

      iex> get_user_profile!(123)
      %UserProfile{}

      iex> get_user_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_profile!(id), do: Repo.get!(UserProfile, id)

  def get_user_profile_by_user(user_id) do
    Repo.get_by(UserProfile, user_id: user_id)
  end

  @doc """
  Creates a user_profile.

  ## Examples

      iex> create_user_profile(%{field: value})
      {:ok, %UserProfile{}}

      iex> create_user_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_profile(attrs \\ %{}) do
    %UserProfile{}
    |> UserProfile.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_user_profile(user_id, attrs) do
    user_id
    |> get_user_profile_by_user()
    |> case do
      nil -> create_user_profile(put_user_id(attrs, user_id))
      %UserProfile{} = profile -> update_user_profile(profile, attrs)
    end
  end

  @doc """
  Updates a user_profile.

  ## Examples

      iex> update_user_profile(user_profile, %{field: new_value})
      {:ok, %UserProfile{}}

      iex> update_user_profile(user_profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_profile(%UserProfile{} = user_profile, attrs) do
    user_profile
    |> UserProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user_profile.

  ## Examples

      iex> delete_user_profile(user_profile)
      {:ok, %UserProfile{}}

      iex> delete_user_profile(user_profile)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_profile(%UserProfile{} = user_profile) do
    Repo.delete(user_profile)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_profile changes.

  ## Examples

      iex> change_user_profile(user_profile)
      %Ecto.Changeset{data: %UserProfile{}}

  """
  def change_user_profile(%UserProfile{} = user_profile, attrs \\ %{}) do
    UserProfile.changeset(user_profile, attrs)
  end

  alias GymBro.Profiles.TrainerProfile

  @doc """
  Returns the list of trainer_profiles.

  ## Examples

      iex> list_trainer_profiles()
      [%TrainerProfile{}, ...]

  """
  def list_trainer_profiles do
    Repo.all(from profile in TrainerProfile, order_by: [asc: profile.inserted_at])
  end

  @doc """
  Gets a single trainer_profile.

  Raises `Ecto.NoResultsError` if the Trainer profile does not exist.

  ## Examples

      iex> get_trainer_profile!(123)
      %TrainerProfile{}

      iex> get_trainer_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_trainer_profile!(id), do: Repo.get!(TrainerProfile, id)

  def get_trainer_profile_by_user(user_id) do
    Repo.get_by(TrainerProfile, user_id: user_id)
  end

  @doc """
  Creates a trainer_profile.

  ## Examples

      iex> create_trainer_profile(%{field: value})
      {:ok, %TrainerProfile{}}

      iex> create_trainer_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_trainer_profile(attrs \\ %{}) do
    %TrainerProfile{}
    |> TrainerProfile.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_trainer_profile(user_id, attrs) do
    user_id
    |> get_trainer_profile_by_user()
    |> case do
      nil -> create_trainer_profile(put_user_id(attrs, user_id))
      %TrainerProfile{} = profile -> update_trainer_profile(profile, attrs)
    end
  end

  @doc """
  Updates a trainer_profile.

  ## Examples

      iex> update_trainer_profile(trainer_profile, %{field: new_value})
      {:ok, %TrainerProfile{}}

      iex> update_trainer_profile(trainer_profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_trainer_profile(%TrainerProfile{} = trainer_profile, attrs) do
    trainer_profile
    |> TrainerProfile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trainer_profile.

  ## Examples

      iex> delete_trainer_profile(trainer_profile)
      {:ok, %TrainerProfile{}}

      iex> delete_trainer_profile(trainer_profile)
      {:error, %Ecto.Changeset{}}

  """
  def delete_trainer_profile(%TrainerProfile{} = trainer_profile) do
    Repo.delete(trainer_profile)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trainer_profile changes.

  ## Examples

      iex> change_trainer_profile(trainer_profile)
      %Ecto.Changeset{data: %TrainerProfile{}}

  """
  def change_trainer_profile(%TrainerProfile{} = trainer_profile, attrs \\ %{}) do
    TrainerProfile.changeset(trainer_profile, attrs)
  end

  defp put_user_id(attrs, user_id) when is_map(attrs) do
    if Enum.all?(Map.keys(attrs), &is_binary/1) do
      Map.put(attrs, "user_id", user_id)
    else
      Map.put(attrs, :user_id, user_id)
    end
  end
end
