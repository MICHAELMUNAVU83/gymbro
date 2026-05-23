defmodule GymBroWeb.Trainer.ClientInviteLive do
  use GymBroWeb, :live_view

  alias GymBro.{Onboarding, Profiles, Trainer}
  alias GymBro.Trainer.ClientInvitation

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    profile = Profiles.get_trainer_profile_by_user(current_user.id)

    if is_nil(profile) do
      {:ok, push_navigate(socket, to: Onboarding.welcome_path(current_user)), layout: false}
    else
      {:ok,
       socket
       |> assign(:page_title, "Invite Client")
       |> assign(:active_nav, :invite)
       |> assign(:profile, profile)
       |> assign(:invitation_form, to_form(Trainer.change_client_invitation(%ClientInvitation{})))
       |> assign_invitations(), layout: {GymBroWeb.Layouts, :trainer_app}}
    end
  end

  @impl true
  def handle_event("validate", %{"client_invitation" => invitation_params}, socket) do
    changeset =
      %ClientInvitation{}
      |> Trainer.change_client_invitation(invitation_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :invitation_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"client_invitation" => invitation_params}, socket) do
    trainer = socket.assigns.current_user

    case Trainer.deliver_client_invitation(trainer, invitation_params, fn token ->
           url(~p"/join/#{token}")
         end) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent.")
         |> assign(
           :invitation_form,
           to_form(Trainer.change_client_invitation(%ClientInvitation{}))
         )
         |> assign_invitations()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(socket, :invitation_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <.back navigate={~p"/trainer/clients"}>Back to clients</.back>
      </div>

      <header>
        <p class="type-label">Client invite</p>
        <h1 class="mt-2 type-h1">Bring the next athlete into your roster.</h1>
        <p class="mt-3 max-w-[60ch] type-body text-text-muted">
          Send a secure GymBro invite link. It expires in 48 hours and routes them into athlete signup automatically.
        </p>
      </header>

      <.form
        for={@invitation_form}
        id="client-invitation-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-4"
      >
        <.input
          field={@invitation_form[:email]}
          type="email"
          label="Athlete email"
          placeholder="client@example.com"
          required
        />

        <button type="submit" class="gb-btn gb-btn--primary gb-btn--block">
          Send invitation
        </button>
      </.form>

      <hr class="gb-divider" />

      <section>
        <p class="type-label">Sent invites</p>
        <ul class="mt-4 divide-y divide-border border-y border-border">
          <li :for={invitation <- @invitations} class="flex items-start justify-between gap-4 py-3">
            <div class="min-w-0">
              <p class="truncate type-h3">{invitation.email}</p>
              <p class="mt-1 type-body-sm">
                Sent {format_timestamp(invitation.inserted_at)} · expires {format_timestamp(
                  invitation.expires_at
                )}
              </p>
            </div>
            <span class={status_classes(invitation.status)}>{invitation.status}</span>
          </li>
          <li :if={@invitations == []} class="py-3 type-body-sm">
            No invites sent yet. Start with one athlete and the invite history will build here.
          </li>
        </ul>
      </section>
    </div>
    """
  end

  defp assign_invitations(socket) do
    assign(socket, :invitations, Trainer.list_client_invitations(socket.assigns.current_user.id))
  end

  defp format_timestamp(nil), do: "n/a"
  defp format_timestamp(datetime), do: Calendar.strftime(datetime, "%b %-d, %Y %H:%M")

  defp status_classes("accepted"), do: "gb-pill gb-pill--success"
  defp status_classes("expired"), do: "gb-pill"
  defp status_classes(_status), do: "gb-pill gb-pill--warning"
end
