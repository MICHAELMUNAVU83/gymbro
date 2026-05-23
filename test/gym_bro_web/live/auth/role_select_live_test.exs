defmodule GymBroWeb.Auth.RoleSelectLiveTest do
  use GymBroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GymBro.AccountsFixtures

  describe "GET /join/role" do
    test "renders the role choices", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/join/role")

      assert html =~ "Welcome to GymBro"
      assert html =~ "Athlete"
      assert html =~ "Trainer"
      assert html =~ "I am joining as a…"
    end

    test "redirects authenticated users away from role selection", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture())

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/join/role")
    end
  end
end
