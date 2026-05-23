defmodule GymBroWeb.RoleSelectionController do
  use GymBroWeb, :controller

  alias GymBro.Accounts.User

  def create(conn, %{"role" => role}) do
    if role in User.registration_roles() do
      conn
      |> put_session(:registration_role, role)
      |> redirect(to: ~p"/users/register")
    else
      conn
      |> put_flash(:error, "Choose whether you're joining as an athlete or trainer.")
      |> redirect(to: ~p"/join/role")
    end
  end
end
