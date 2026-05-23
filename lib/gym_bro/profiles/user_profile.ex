defmodule GymBro.Profiles.UserProfile do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User

  @fitness_levels ~w(beginner intermediate advanced)
  @goals ~w(weight_loss muscle_gain maintenance)
  @equipment_options ~w(gym home minimal)
  @preferred_exercises_per_day_options [3, 4, 5, 6]
  @preferred_block_week_options Enum.to_list(3..16)
  @day_numbers Enum.to_list(1..7)

  schema "user_profiles" do
    field :age, :integer
    field :height_cm, :float
    field :weight_kg, :float
    field :goal_weight_kg, :float
    field :preferred_session_minutes, :integer
    field :fitness_level, :string
    field :goal, :string
    field :days_per_week, :integer
    field :preferred_rest_days, {:array, :integer}, default: []
    field :preferred_exercises_per_day, :integer
    field :preferred_block_weeks, :integer, default: 9
    field :equipment, :string
    field :onboarding_complete, :boolean, default: false
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_profile, attrs) do
    attrs = normalize_profile_attrs(attrs)

    user_profile
    |> cast(attrs, [
      :user_id,
      :age,
      :height_cm,
      :weight_kg,
      :goal_weight_kg,
      :preferred_session_minutes,
      :fitness_level,
      :goal,
      :days_per_week,
      :preferred_rest_days,
      :preferred_exercises_per_day,
      :preferred_block_weeks,
      :equipment,
      :onboarding_complete
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:fitness_level, @fitness_levels)
    |> validate_inclusion(:goal, @goals)
    |> validate_inclusion(:equipment, @equipment_options)
    |> validate_inclusion(:days_per_week, [3, 4, 5])
    |> validate_inclusion(:preferred_session_minutes, [30, 45, 60, 75, 90])
    |> validate_inclusion(:preferred_exercises_per_day, @preferred_exercises_per_day_options)
    |> validate_inclusion(:preferred_block_weeks, @preferred_block_week_options)
    |> validate_number(:age, greater_than: 0)
    |> validate_number(:height_cm, greater_than: 0.0)
    |> validate_number(:weight_kg, greater_than: 0.0)
    |> validate_number(:goal_weight_kg, greater_than: 0.0)
    |> validate_rest_days()
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id)
  end

  defp normalize_profile_attrs(attrs) when is_map(attrs) do
    attrs
    |> normalize_rest_days(:preferred_rest_days)
    |> normalize_rest_days("preferred_rest_days")
  end

  defp normalize_rest_days(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, rest_days} when is_list(rest_days) ->
        Map.put(attrs, key, Enum.reject(rest_days, &(&1 in ["", nil])))

      _ ->
        attrs
    end
  end

  defp validate_rest_days(changeset) do
    rest_days = get_field(changeset, :preferred_rest_days, [])
    days_per_week = get_field(changeset, :days_per_week)
    unique_rest_days = Enum.uniq(rest_days)

    changeset
    |> validate_subset(:preferred_rest_days, @day_numbers)
    |> maybe_add_rest_day_uniqueness_error(rest_days, unique_rest_days)
    |> maybe_add_rest_day_count_error(days_per_week, unique_rest_days)
  end

  defp maybe_add_rest_day_uniqueness_error(changeset, rest_days, unique_rest_days) do
    if length(rest_days) == length(unique_rest_days) do
      changeset
    else
      add_error(changeset, :preferred_rest_days, "must not contain duplicate days")
    end
  end

  defp maybe_add_rest_day_count_error(changeset, nil, _unique_rest_days), do: changeset

  defp maybe_add_rest_day_count_error(changeset, _days_per_week, unique_rest_days)
       when unique_rest_days in [nil, []] do
    changeset
  end

  defp maybe_add_rest_day_count_error(changeset, days_per_week, unique_rest_days) do
    required_rest_days = 7 - days_per_week

    if length(unique_rest_days) == required_rest_days do
      changeset
    else
      add_error(
        changeset,
        :preferred_rest_days,
        "must include exactly #{required_rest_days} rest day#{if required_rest_days == 1, do: "", else: "s"}"
      )
    end
  end
end
