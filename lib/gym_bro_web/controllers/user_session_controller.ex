defmodule GymBroWeb.UserSessionController do
  use GymBroWeb, :controller

  alias GymBro.Accounts
  alias GymBro.Trainer
  alias GymBroWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      {conn, flash_level, flash_message} = maybe_accept_pending_invitation(conn, user)

      conn
      |> put_flash(flash_level, flash_message)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, :new, error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  defp maybe_accept_pending_invitation(conn, user) do
    case get_session(conn, :client_invitation_token) do
      nil ->
        {conn, :info, "Welcome back!"}

      token ->
        case Trainer.accept_client_invitation(token, user) do
          {:ok, _trainer_client} ->
            {clear_invitation_session(conn), :info,
             "Welcome back! Your trainer invite is active."}

          {:error, :email_mismatch} ->
            {clear_invitation_session(conn), :error,
             "This trainer invite belongs to a different email address."}

          {:error, :expired} ->
            {clear_invitation_session(conn), :error,
             "That trainer invite expired before you logged in."}

          {:error, :accepted} ->
            {clear_invitation_session(conn), :info,
             "Welcome back! That trainer invite was already accepted."}

          {:error, _reason} ->
            {clear_invitation_session(conn), :error,
             "We couldn't activate that trainer invite, but your login still worked."}
        end
    end
  end

  defp clear_invitation_session(conn) do
    conn
    |> delete_session(:client_invitation_token)
    |> delete_session(:registration_role)
  end
end
