defmodule GymBro.BodyStats do
  @moduledoc """
  The BodyStats context.
  """

  import Ecto.Query, warn: false
  alias GymBro.Repo

  alias GymBro.BodyStats.BodyWeightLog

  @doc """
  Returns the list of body_weight_logs.

  ## Examples

      iex> list_body_weight_logs()
      [%BodyWeightLog{}, ...]

  """
  def list_body_weight_logs do
    Repo.all(from log in BodyWeightLog, order_by: [desc: log.logged_at, desc: log.inserted_at])
  end

  def list_body_weight_logs_for_user(user_id) do
    Repo.all(
      from log in BodyWeightLog,
        where: log.user_id == ^user_id,
        order_by: [desc: log.logged_at, desc: log.inserted_at]
    )
  end

  def list_body_weight_logs_for_user_chronological(user_id) do
    Repo.all(
      from log in BodyWeightLog,
        where: log.user_id == ^user_id,
        order_by: [asc: log.logged_at, asc: log.inserted_at]
    )
  end

  def list_recent_body_weight_logs_for_user(user_id, limit \\ 8) do
    Repo.all(
      from log in BodyWeightLog,
        where: log.user_id == ^user_id,
        order_by: [desc: log.logged_at, desc: log.inserted_at],
        limit: ^limit
    )
    |> Enum.reverse()
  end

  def latest_body_weight_log(user_id) do
    Repo.one(
      from log in BodyWeightLog,
        where: log.user_id == ^user_id,
        order_by: [desc: log.logged_at, desc: log.inserted_at],
        limit: 1
    )
  end

  @doc """
  Gets a single body_weight_log.

  Raises `Ecto.NoResultsError` if the Body weight log does not exist.

  ## Examples

      iex> get_body_weight_log!(123)
      %BodyWeightLog{}

      iex> get_body_weight_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_body_weight_log!(id), do: Repo.get!(BodyWeightLog, id)

  @doc """
  Creates a body_weight_log.

  ## Examples

      iex> create_body_weight_log(%{field: value})
      {:ok, %BodyWeightLog{}}

      iex> create_body_weight_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_body_weight_log(attrs \\ %{}) do
    %BodyWeightLog{}
    |> BodyWeightLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a body_weight_log.

  ## Examples

      iex> update_body_weight_log(body_weight_log, %{field: new_value})
      {:ok, %BodyWeightLog{}}

      iex> update_body_weight_log(body_weight_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_body_weight_log(%BodyWeightLog{} = body_weight_log, attrs) do
    body_weight_log
    |> BodyWeightLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a body_weight_log.

  ## Examples

      iex> delete_body_weight_log(body_weight_log)
      {:ok, %BodyWeightLog{}}

      iex> delete_body_weight_log(body_weight_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_body_weight_log(%BodyWeightLog{} = body_weight_log) do
    Repo.delete(body_weight_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking body_weight_log changes.

  ## Examples

      iex> change_body_weight_log(body_weight_log)
      %Ecto.Changeset{data: %BodyWeightLog{}}

  """
  def change_body_weight_log(%BodyWeightLog{} = body_weight_log, attrs \\ %{}) do
    BodyWeightLog.changeset(body_weight_log, attrs)
  end

  alias GymBro.BodyStats.CheckinImage

  @doc """
  Returns the list of checkin_images.

  ## Examples

      iex> list_checkin_images()
      [%CheckinImage{}, ...]

  """
  def list_checkin_images do
    Repo.all(
      from image in CheckinImage, order_by: [desc: image.logged_at, desc: image.inserted_at]
    )
  end

  def list_checkin_images_for_user(user_id) do
    Repo.all(
      from image in CheckinImage,
        where: image.user_id == ^user_id,
        order_by: [desc: image.logged_at, desc: image.inserted_at]
    )
  end

  def list_checkin_images_for_user_by_type(user_id, image_type) do
    Repo.all(
      from image in CheckinImage,
        where: image.user_id == ^user_id and image.image_type == ^image_type,
        order_by: [desc: image.logged_at, desc: image.inserted_at]
    )
  end

  @doc """
  Gets a single checkin_image.

  Raises `Ecto.NoResultsError` if the Checkin image does not exist.

  ## Examples

      iex> get_checkin_image!(123)
      %CheckinImage{}

      iex> get_checkin_image!(456)
      ** (Ecto.NoResultsError)

  """
  def get_checkin_image!(id), do: Repo.get!(CheckinImage, id)

  @doc """
  Creates a checkin_image.

  ## Examples

      iex> create_checkin_image(%{field: value})
      {:ok, %CheckinImage{}}

      iex> create_checkin_image(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_checkin_image(attrs \\ %{}) do
    %CheckinImage{}
    |> CheckinImage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a checkin_image.

  ## Examples

      iex> update_checkin_image(checkin_image, %{field: new_value})
      {:ok, %CheckinImage{}}

      iex> update_checkin_image(checkin_image, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_checkin_image(%CheckinImage{} = checkin_image, attrs) do
    checkin_image
    |> CheckinImage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a checkin_image.

  ## Examples

      iex> delete_checkin_image(checkin_image)
      {:ok, %CheckinImage{}}

      iex> delete_checkin_image(checkin_image)
      {:error, %Ecto.Changeset{}}

  """
  def delete_checkin_image(%CheckinImage{} = checkin_image) do
    Repo.delete(checkin_image)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking checkin_image changes.

  ## Examples

      iex> change_checkin_image(checkin_image)
      %Ecto.Changeset{data: %CheckinImage{}}

  """
  def change_checkin_image(%CheckinImage{} = checkin_image, attrs \\ %{}) do
    CheckinImage.changeset(checkin_image, attrs)
  end

  alias GymBro.BodyStats.PersonalRecord

  @doc """
  Returns the list of personal_records.

  ## Examples

      iex> list_personal_records()
      [%PersonalRecord{}, ...]

  """
  def list_personal_records do
    Repo.all(
      from record in PersonalRecord,
        order_by: [desc: record.achieved_at, desc: record.inserted_at]
    )
  end

  def list_personal_records_for_user(user_id) do
    Repo.all(
      from record in PersonalRecord,
        where: record.user_id == ^user_id,
        order_by: [desc: record.achieved_at, desc: record.inserted_at]
    )
  end

  @doc """
  Gets a single personal_record.

  Raises `Ecto.NoResultsError` if the Personal record does not exist.

  ## Examples

      iex> get_personal_record!(123)
      %PersonalRecord{}

      iex> get_personal_record!(456)
      ** (Ecto.NoResultsError)

  """
  def get_personal_record!(id), do: Repo.get!(PersonalRecord, id)

  @doc """
  Creates a personal_record.

  ## Examples

      iex> create_personal_record(%{field: value})
      {:ok, %PersonalRecord{}}

      iex> create_personal_record(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_personal_record(attrs \\ %{}) do
    %PersonalRecord{}
    |> PersonalRecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a personal_record.

  ## Examples

      iex> update_personal_record(personal_record, %{field: new_value})
      {:ok, %PersonalRecord{}}

      iex> update_personal_record(personal_record, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_personal_record(%PersonalRecord{} = personal_record, attrs) do
    personal_record
    |> PersonalRecord.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a personal_record.

  ## Examples

      iex> delete_personal_record(personal_record)
      {:ok, %PersonalRecord{}}

      iex> delete_personal_record(personal_record)
      {:error, %Ecto.Changeset{}}

  """
  def delete_personal_record(%PersonalRecord{} = personal_record) do
    Repo.delete(personal_record)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking personal_record changes.

  ## Examples

      iex> change_personal_record(personal_record)
      %Ecto.Changeset{data: %PersonalRecord{}}

  """
  def change_personal_record(%PersonalRecord{} = personal_record, attrs \\ %{}) do
    PersonalRecord.changeset(personal_record, attrs)
  end
end
