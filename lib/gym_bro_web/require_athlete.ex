defmodule GymBroWeb.RequireAthlete do
  use GymBroWeb, :verified_routes

  def on_mount(:default, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %{role: "athlete"} ->
        {:cont, socket}

      nil ->
        {:halt, redirect_unauthenticated(socket)}

      _user ->
        {:halt, redirect_unauthorized(socket)}
    end
  end

  defp redirect_unauthenticated(socket) do
    socket
    |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
    |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")
  end

  defp redirect_unauthorized(socket) do
    socket
    |> Phoenix.LiveView.put_flash(:error, "Athlete access is required for this page.")
    |> Phoenix.LiveView.redirect(to: "/trainer")
  end
end
