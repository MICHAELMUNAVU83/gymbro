defmodule GymBro.BodyStats.CheckinImage do
  use Ecto.Schema
  import Ecto.Changeset

  alias GymBro.Accounts.User

  schema "checkin_images" do
    field :image_url, :string
    field :image_type, :string
    field :logged_at, :date
    field :notes, :string
    field :visible_to_trainer, :boolean, default: true
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(checkin_image, attrs) do
    checkin_image
    |> cast(attrs, [:user_id, :image_url, :image_type, :logged_at, :notes, :visible_to_trainer])
    |> validate_required([:user_id, :image_url])
    |> foreign_key_constraint(:user_id)
  end
end
