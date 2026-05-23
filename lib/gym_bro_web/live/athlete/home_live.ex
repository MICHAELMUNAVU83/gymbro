defmodule GymBroWeb.Athlete.HomeLive do
  use GymBroWeb, :live_view

  alias GymBro.{Dashboard, Onboarding, Profiles}
  alias GymBroWeb.PageHTML

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case Onboarding.next_path(current_user) do
      "/" ->
        profile = Profiles.get_user_profile_by_user(current_user.id)

        {:ok,
         socket
         |> assign(:active_nav, :home)
         |> assign(:page_title, "Athlete Home")
         |> assign(:profile, profile)
         |> assign(:dashboard, Dashboard.athlete_home(current_user, profile))}

      path ->
        {:ok, push_navigate(socket, to: path), layout: false}
    end
  end

  @impl true
  def render(assigns), do: PageHTML.dashboard(assigns)
end
