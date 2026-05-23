defmodule GymBroWeb.RoleAuthorizationTest do
  use GymBroWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias GymBroWeb.{RequireAthlete, RequireTrainer}

  import GymBro.AccountsFixtures

  describe "RequireTrainer.on_mount/4" do
    test "allows trainers through" do
      trainer = user_fixture(%{role: "trainer"})

      assert {:cont, socket} =
               RequireTrainer.on_mount(:default, %{}, %{}, build_socket(%{current_user: trainer}))

      assert socket.assigns.current_user.id == trainer.id
    end

    test "redirects athletes to the home page" do
      athlete = user_fixture()

      assert {:halt, socket} =
               RequireTrainer.on_mount(:default, %{}, %{}, build_socket(%{current_user: athlete}))

      assert {:redirect, %{to: "/"}} = socket.redirected
    end

    test "redirects unauthenticated users to log in" do
      assert {:halt, socket} = RequireTrainer.on_mount(:default, %{}, %{}, build_socket())

      assert {:redirect, %{to: "/users/log_in"}} = socket.redirected
    end
  end

  describe "RequireAthlete.on_mount/4" do
    test "allows athletes through" do
      athlete = user_fixture()

      assert {:cont, socket} =
               RequireAthlete.on_mount(:default, %{}, %{}, build_socket(%{current_user: athlete}))

      assert socket.assigns.current_user.id == athlete.id
    end

    test "redirects trainers to the trainer dashboard" do
      trainer = user_fixture(%{role: "trainer"})

      assert {:halt, socket} =
               RequireAthlete.on_mount(:default, %{}, %{}, build_socket(%{current_user: trainer}))

      assert {:redirect, %{to: "/trainer"}} = socket.redirected
    end

    test "redirects unauthenticated users to log in" do
      assert {:halt, socket} = RequireAthlete.on_mount(:default, %{}, %{}, build_socket())

      assert {:redirect, %{to: "/users/log_in"}} = socket.redirected
    end
  end

  defp build_socket(assigns \\ %{}) do
    %LiveView.Socket{
      endpoint: GymBroWeb.Endpoint,
      assigns: Map.merge(%{__changed__: %{}, flash: %{}}, assigns)
    }
  end
end
