defmodule GymBroWeb.HomeLive do
  use GymBroWeb, :live_view

  alias GymBro.Onboarding
  alias GymBroWeb.HomeComponents

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:ok,
         socket
         |> assign(:mobile_menu_open, false)
         |> assign(:page_title, "Free AI Workout Plans")
         |> assign(
           :page_description,
           "GymBro helps athletes and trainers create AI-powered workout plans, log every session, and track progress in one coaching platform."
         )
         |> assign(:page_robots, "index,follow")
         |> assign(:canonical_url, "#{GymBroWeb.Endpoint.url()}/")
         |> assign(:page_image_url, "#{GymBroWeb.Endpoint.url()}#{~p"/images/logobg.png"}")
         |> assign(
           :structured_data,
           %{
             "@context" => "https://schema.org",
             "@type" => "WebSite",
             "name" => "GymBro",
             "url" => "#{GymBroWeb.Endpoint.url()}/",
             "description" =>
               "GymBro helps athletes and trainers create AI-powered workout plans, log every session, and track progress in one coaching platform."
           }
         ), layout: false}

      %{role: "athlete"} = current_user ->
        case Onboarding.next_path(current_user) do
          "/" ->
            {:ok, redirect(socket, to: ~p"/home"), layout: false}

          path ->
            {:ok, redirect(socket, to: path), layout: false}
        end

      current_user ->
        {:ok, redirect(socket, to: Onboarding.next_path(current_user)), layout: false}
    end
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, update(socket, :mobile_menu_open, &(!&1))}
  end

  @impl true
  def handle_event("close_mobile_menu", _params, socket) do
    {:noreply, assign(socket, :mobile_menu_open, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <HomeComponents.page flash={@flash} mobile_menu_open={@mobile_menu_open} />
    """
  end
end
