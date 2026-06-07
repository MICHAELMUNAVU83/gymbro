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
         |> assign(:page_title, "Free AI Workout Plans"), layout: false}

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
  def render(assigns) do
    ~H"""
    <HomeComponents.page flash={@flash} mobile_menu_open={@mobile_menu_open} />
    """
  end
end
