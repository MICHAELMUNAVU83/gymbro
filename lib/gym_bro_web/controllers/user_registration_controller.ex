defmodule GymBroWeb.UserRegistrationController do
  use GymBroWeb, :controller

  alias GymBro.Accounts
  alias GymBro.Accounts.User
  alias GymBro.Trainer
  alias GymBroWeb.UserAuth

  def new(conn, _params) do
    with {:ok, invitation} <- registration_invitation(conn),
         {:ok, role} <- selected_registration_role(conn, invitation) do
      changeset = registration_changeset(role, invitation)

      render(conn, :new,
        changeset: changeset,
        invited_email: invitation && invitation.email,
        selected_role: role
      )
    else
      {:error, conn, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/join/role")

      :error ->
        conn
        |> put_flash(:error, "Choose whether you're joining as an athlete or trainer first.")
        |> redirect(to: ~p"/join/role")
    end
  end

  def create(conn, %{"user" => user_params}) do
    with {:ok, invitation} <- registration_invitation(conn),
         {:ok, role} <- selected_registration_role(conn, invitation) do
      case register_user(user_params, role, invitation) do
        {:ok, user} ->
          {:ok, _} =
            Accounts.deliver_user_confirmation_instructions(
              user,
              &url(~p"/users/confirm/#{&1}")
            )

          conn
          |> put_flash(:info, "User created successfully.")
          |> UserAuth.log_in_user(user)

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, :new,
            changeset: changeset,
            invited_email: invitation && invitation.email,
            selected_role: role
          )

        {:error, reason} ->
          conn
          |> clear_invitation_session()
          |> put_flash(:error, invitation_error_message(reason))
          |> redirect(to: ~p"/join/role")
      end
    else
      {:error, conn, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: ~p"/join/role")

      :error ->
        conn
        |> put_flash(:error, "Choose whether you're joining as an athlete or trainer first.")
        |> redirect(to: ~p"/join/role")
    end
  end

  defp selected_registration_role(_conn, invitation) when not is_nil(invitation),
    do: {:ok, "athlete"}

  defp selected_registration_role(conn, _invitation) do
    role = get_session(conn, :registration_role)

    if role in User.registration_roles() do
      {:ok, role}
    else
      :error
    end
  end

  defp register_user(user_params, role, nil) do
    Accounts.register_user(Map.put(user_params, "role", role))
  end

  defp register_user(user_params, _role, invitation) do
    Trainer.register_invited_client(user_params, invitation.token)
  end

  defp registration_invitation(conn) do
    case get_session(conn, :client_invitation_token) do
      nil ->
        {:ok, nil}

      token ->
        case Trainer.fetch_joinable_client_invitation(token) do
          {:ok, invitation} ->
            {:ok, invitation}

          {:error, reason} ->
            {:error, clear_invitation_session(conn), invitation_error_message(reason)}
        end
    end
  end

  defp registration_changeset(role, nil) do
    Accounts.change_user_registration(%User{role: role})
  end

  defp registration_changeset(role, invitation) do
    Accounts.change_user_registration(%User{role: role}, %{"email" => invitation.email})
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
