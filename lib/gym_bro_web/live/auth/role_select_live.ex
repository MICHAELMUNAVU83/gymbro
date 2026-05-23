defmodule GymBroWeb.Auth.RoleSelectLive do
  use GymBroWeb, :live_view

  @role_cards [
    %{
      value: "athlete",
      title: "Athlete",
      tagline: "Track my own workouts",
      detail: "Follow AI-built programs, log training, and see progress week by week."
    },
    %{
      value: "trainer",
      title: "Trainer",
      tagline: "Manage clients and results",
      detail: "Assign programs, monitor progress, and support athletes in real time."
    }
  ]

  def render(assigns) do
    assigns = assign(assigns, :role_cards, @role_cards)

    ~H"""
    <div class="app-shell py-10">
      <div class="mx-auto max-w-xl">
        <p class="type-label">Welcome to GymBro</p>
        <h1 class="mt-3 type-h1">I am joining as a…</h1>
        <p class="mt-3 type-body text-text-muted">
          Pick the experience you want first. We'll carry that choice into registration.
        </p>

        <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.form
            :for={role <- @role_cards}
            for={%{}}
            action={~p"/join/role"}
            method="post"
          >
            <button
              type="submit"
              value={role.value}
              name="role"
              class="gb-card flex w-full flex-col items-start text-left transition hover:border-border-strong"
            >
              <p class="type-label">Role</p>
              <p class="mt-1 type-h2">{role.title}</p>
              <p class="mt-1 type-body-sm">{role.tagline}</p>
              <p class="mt-4 type-body">{role.detail}</p>
              <span class="mt-6 gb-btn gb-btn--primary gb-btn--sm">Choose</span>
            </button>
          </.form>
        </div>

        <p class="mt-8 type-body-sm">
          Already registered?
          <.link navigate={~p"/users/log_in"} class="gb-link--accent ml-1">Log in</.link>
        </p>
      </div>
    </div>
    """
  end
end
