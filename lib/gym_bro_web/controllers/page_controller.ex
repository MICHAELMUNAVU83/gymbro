defmodule GymBroWeb.PageController do
  use GymBroWeb, :controller

  alias GymBro.Onboarding

  def home(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        render(conn, :home, layout: false)

      %{role: "athlete"} = current_user ->
        case Onboarding.next_path(current_user) do
          "/" ->
            redirect(conn, to: ~p"/home")

          path ->
            redirect(conn, to: path)
        end

      current_user ->
        redirect(conn, to: Onboarding.next_path(current_user))
    end
  end
end
