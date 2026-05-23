defmodule GymBroWeb.UserRegistrationControllerTest do
  use GymBroWeb.ConnCase, async: true

  alias GymBro.Accounts
  alias GymBro.Trainer
  import GymBro.AccountsFixtures
  import GymBro.TrainerFixtures

  describe "GET /users/register" do
    test "redirects to role selection when no role is stored", %{conn: conn} do
      conn = get(conn, ~p"/users/register")

      assert redirected_to(conn) == ~p"/join/role"
    end

    test "renders registration page for the selected role", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{registration_role: "trainer"})
        |> get(~p"/users/register")

      response = html_response(conn, 200)
      assert response =~ "Create your Trainer account"
      assert response =~ "Change role"
      assert response =~ ~p"/users/log_in"
      assert response =~ ~p"/users/register"
    end

    test "renders the invited athlete registration page when an invitation is in session", %{
      conn: conn
    } do
      invitation = client_invitation_fixture(%{email: "invited.client@example.com"})

      conn =
        conn
        |> init_test_session(%{
          client_invitation_token: invitation.token,
          registration_role: "athlete"
        })
        |> get(~p"/users/register")

      response = html_response(conn, 200)
      assert response =~ "Create your Athlete account"
      assert response =~ "invited.client@example.com"
      assert response =~ "locks signup to"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /users/register" do
    @tag :capture_log
    test "creates account and logs the user in", %{conn: conn} do
      email = unique_user_email()

      conn =
        conn
        |> init_test_session(%{registration_role: "trainer"})
        |> post(~p"/users/register", %{
          "user" => valid_user_attributes(email: email)
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_user_by_email(email).role == "trainer"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/onboarding/trainer-setup"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{registration_role: "athlete"})
        |> post(~p"/users/register", %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "Create your Athlete account"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end

    @tag :capture_log
    test "creates an invited athlete account and links the trainer", %{conn: conn} do
      trainer = user_fixture(%{role: "trainer"})

      invitation =
        client_invitation_fixture(%{
          email: "linked.client@example.com",
          trainer_id: trainer.id
        })

      conn =
        conn
        |> init_test_session(%{
          client_invitation_token: invitation.token,
          registration_role: "athlete"
        })
        |> post(~p"/users/register", %{
          "user" => valid_user_attributes(email: "ignored@example.com")
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      user = Accounts.get_user_by_email("linked.client@example.com")
      assert user.role == "athlete"
      assert Trainer.get_trainer_client(trainer.id, user.id)
      assert Trainer.get_client_invitation_by_token(invitation.token).status == "accepted"
    end

    test "redirects back to role selection when the role is missing", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes()
        })

      assert redirected_to(conn) == ~p"/join/role"
    end
  end
end
