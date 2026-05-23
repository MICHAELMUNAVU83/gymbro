defmodule GymBroWeb.ClientInvitationController do
  use GymBroWeb, :controller

  alias GymBro.{Accounts, Trainer}

  def show(conn, %{"token" => token}) do
    case Trainer.fetch_joinable_client_invitation(token) do
      {:ok, invitation} ->
        case conn.assigns[:current_user] do
          nil ->
            conn
            |> put_session(:registration_role, "athlete")
            |> put_session(:client_invitation_token, token)
            |> redirect_for_invitation(invitation)

          current_user ->
            redirect_authenticated_user(conn, token, current_user)
        end

      {:error, reason} ->
        conn
        |> clear_invitation_session()
        |> put_flash(:error, invitation_error_message(reason))
        |> redirect(to: ~p"/join/role")
    end
  end

  defp redirect_for_invitation(conn, invitation) do
    if Accounts.get_user_by_email(invitation.email) do
      conn
      |> put_flash(:info, "Log in with #{invitation.email} to accept your trainer invite.")
      |> redirect(to: ~p"/users/log_in")
    else
      conn
      |> put_flash(
        :info,
        "Finish creating your athlete account to join your trainer on GymBro."
      )
      |> redirect(to: ~p"/users/register")
    end
  end

  defp redirect_authenticated_user(conn, token, current_user) do
    case Trainer.accept_client_invitation(token, current_user) do
      {:ok, _trainer_client} ->
        conn
        |> clear_invitation_session()
        |> put_flash(:info, "Trainer invite accepted.")
        |> redirect(to: ~p"/")

      {:error, :email_mismatch} ->
        conn
        |> clear_invitation_session()
        |> put_flash(:error, "This trainer invite belongs to a different email address.")
        |> redirect(to: ~p"/")

      {:error, reason} ->
        conn
        |> clear_invitation_session()
        |> put_flash(:error, invitation_error_message(reason))
        |> redirect(to: ~p"/")
    end
  end

  defp clear_invitation_session(conn) do
    conn
    |> delete_session(:client_invitation_token)
    |> delete_session(:registration_role)
  end

  defp invitation_error_message(:expired),
    do: "That invitation has expired. Ask your trainer for a new link."

  defp invitation_error_message(:accepted), do: "That invitation link has already been used."
  defp invitation_error_message(_), do: "We couldn't find that invitation link."
end
