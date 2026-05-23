defmodule GymBroWeb.Trainer.ClientListLive do
  use GymBroWeb, :live_view

  alias GymBro.{Onboarding, Profiles, Trainer}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = Profiles.get_trainer_profile_by_user(current_user.id)

    if is_nil(profile) do
      {:ok, push_navigate(socket, to: Onboarding.welcome_path(current_user)), layout: false}
    else
      {:ok,
       socket
       |> assign(:profile, profile)
       |> assign(:active_nav, :clients)
       |> assign(:page_title, "Clients")
       |> assign_client_list(""), layout: {GymBroWeb.Layouts, :trainer_app}}
    end
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    {:noreply, assign_client_list(socket, query)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <header class="flex items-start justify-between gap-4">
        <div>
          <p class="type-label">Trainer roster</p>
          <h1 class="mt-2 type-h1">Every client, one clean queue.</h1>
          <p class="mt-3 max-w-[60ch] type-body text-text-muted">
            Search the full roster, jump into a client file, and tune their plan without losing context.
          </p>
        </div>
        <.link href={~p"/trainer/clients/invite"} class="gb-btn gb-btn--primary">
          Invite athlete
        </.link>
      </header>

      <.form id="client-search-form" for={@search_form} phx-change="search">
        <.input
          field={@search_form[:query]}
          type="text"
          label={"#{length(@clients)} clients"}
          placeholder="Search by name or email"
        />
      </.form>

      <section class="space-y-4">
        <.link
          :for={client <- @clients}
          href={~p"/trainer/clients/#{client.id}"}
          class="gb-card block transition hover:border-border-strong"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <div class="flex items-center gap-3">
                <div class="grid h-10 w-10 flex-none place-items-center rounded-pill bg-surface-alt text-sm font-semibold text-text">
                  {initials(client.display_name)}
                </div>
                <div class="min-w-0">
                  <h2 class="truncate type-h3">{client.display_name}</h2>
                  <p class="truncate type-body-sm">{client.email}</p>
                </div>
              </div>

              <div class="mt-4 flex flex-wrap gap-2">
                <span class="gb-pill">{client.status}</span>
                <span class="gb-pill">{client.goal_label}</span>
                <span class="gb-pill">{client.schedule_label}</span>
              </div>

              <p class="mt-4 type-body-sm">
                {client.notes ||
                  "No relationship notes yet. Open the client file to review stats, the current program, photos, and PRs."}
              </p>
            </div>

            <dl class="hidden text-right text-xs sm:block">
              <dt class="type-label">Level</dt>
              <dd class="mt-1 type-body-sm">{client.fitness_level_label}</dd>
              <dt class="mt-4 type-label">Joined</dt>
              <dd class="mt-1 type-body-sm">{format_joined_at(client.joined_at)}</dd>
            </dl>
          </div>
        </.link>

        <p :if={@clients == []} class="type-body-sm">
          No clients match this search yet. Try another name or email, or add athletes once the invitation flow is in place.
        </p>
      </section>
    </div>
    """
  end

  defp assign_client_list(socket, query) do
    query = query || ""

    socket
    |> assign(:clients, Trainer.list_managed_clients(socket.assigns.current_user.id, query))
    |> assign(:search_form, to_form(%{"query" => query}, as: :search))
  end

  defp initials(name) do
    name
    |> to_string()
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
  end

  defp format_joined_at(nil), do: "Pending"
  defp format_joined_at(joined_at), do: Calendar.strftime(joined_at, "%b %-d, %Y")
end
