defmodule GymBro.Programs.Program do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User
  alias GymBro.Programs.WorkoutDay

  @statuses ~w(active completed paused draft)
  @sources ~w(ai trainer ai_trainer_edited)

  schema "programs" do
    field :name, :string
    field :status, :string
    field :description, :string
    field :source, :string
    field :total_weeks, :integer
    field :current_week, :integer
    field :current_phase, :integer
    field :phase_name, :string
    field :ai_raw_plan, :map
    belongs_to :user, User
    belongs_to :created_by, User
    has_many :workout_days, WorkoutDay

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(program, attrs) do
    program
    |> cast(attrs, [
      :user_id,
      :created_by_id,
      :name,
      :description,
      :total_weeks,
      :current_week,
      :current_phase,
      :phase_name,
      :status,
      :source,
      :ai_raw_plan
    ])
    |> validate_required([
      :user_id,
      :created_by_id,
      :total_weeks,
      :current_week,
      :current_phase,
      :status,
      :source
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:source, @sources)
    |> validate_number(:total_weeks, greater_than: 0)
    |> validate_number(:current_week, greater_than: 0)
    |> validate_number(:current_phase, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:created_by_id)
  end
end
