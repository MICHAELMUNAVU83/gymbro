defmodule GymBro.Repo do
  use Ecto.Repo,
    otp_app: :gym_bro,
    adapter: Ecto.Adapters.Postgres
end
