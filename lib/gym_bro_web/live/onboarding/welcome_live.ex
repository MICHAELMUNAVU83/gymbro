defmodule GymBroWeb.Onboarding.WelcomeLive do
  use GymBroWeb, :live_view

  alias GymBro.Onboarding

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if Onboarding.onboarding_complete?(current_user) do
      {:ok, push_navigate(socket, to: Onboarding.next_path(current_user)), layout: false}
    else
      assigns =
        socket
        |> assign(:role_label, role_label(current_user.role))
        |> assign(:continue_path, Onboarding.welcome_path(current_user))
        |> assign(:headline, headline(current_user.role))
        |> assign(:detail, detail(current_user.role))
        |> assign(:checklist, checklist(current_user.role))

      {:ok, assigns, layout: false}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="app-shell py-10">
      <.flash_group flash={@flash} />

      <div class="mx-auto max-w-xl">
        <p class="type-label">{@role_label} onboarding</p>
        <h1 class="mt-3 type-h1">{@headline}</h1>
        <p class="mt-3 max-w-[60ch] type-body text-text-muted">{@detail}</p>

        <hr class="gb-divider mt-8" />

        <p class="type-label">What we'll set up</p>
        <ul class="mt-4 space-y-3">
          <li :for={item <- @checklist} class="flex items-start gap-3">
            <span class="mt-1 grid h-5 w-5 flex-none place-items-center rounded-pill bg-accent-soft">
              <.icon name="hero-check-mini" class="h-3 w-3 text-accent" />
            </span>
            <p class="type-body">{item}</p>
          </li>
        </ul>

        <.link navigate={@continue_path} class="gb-btn gb-btn--primary gb-btn--lg gb-btn--block mt-10">
          Continue
        </.link>
      </div>
    </div>
    """
  end

  defp role_label("trainer"), do: "Trainer"
  defp role_label(_), do: "Athlete"

  defp headline("trainer"), do: "Build your coaching space"
  defp headline(_), do: "Let's shape your first plan"

  defp detail("trainer") do
    "A quick setup gets your coaching profile ready so clients can recognize your specialty and trust what you prescribe."
  end

  defp detail(_) do
    "We only need a few details about your body stats and training goals before GymBro can start guiding your workouts."
  end

  defp checklist("trainer") do
    [
      "Add your coaching bio, specialization, and certification details.",
      "Set the capacity you want to manage from day one.",
      "Head straight into your trainer dashboard when you're done."
    ]
  end

  defp checklist(_) do
    [
      "Capture your starting age, height, and current bodyweight.",
      "Pick the goal, experience level, and schedule that fit your routine.",
      "Generate your athlete profile, then land on your home dashboard."
    ]
  end
end
