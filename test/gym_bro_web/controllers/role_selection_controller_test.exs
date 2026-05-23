defmodule GymBroWeb.RoleSelectionControllerTest do
  use GymBroWeb.ConnCase, async: true

  describe "POST /join/role" do
    test "stores the selected role in the session", %{conn: conn} do
      conn = post(conn, ~p"/join/role", %{"role" => "trainer"})

      assert get_session(conn, :registration_role) == "trainer"
      assert redirected_to(conn) == ~p"/users/register"
    end

    test "rejects unknown roles", %{conn: conn} do
      conn = post(conn, ~p"/join/role", %{"role" => "admin"})

      assert redirected_to(conn) == ~p"/join/role"
      assert get_flash(conn, :error) =~ "Choose whether you're joining"
    end
  end
end
