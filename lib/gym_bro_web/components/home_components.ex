defmodule GymBroWeb.HomeComponents do
  use GymBroWeb, :html

  attr :flash, :map, required: true
  attr :mobile_menu_open, :boolean, default: false

  def page(assigns) do
    ~H"""
    <div class="min-h-screen bg-bg text-text">
      <.flash_group flash={@flash} />
      <.home_header mobile_menu_open={@mobile_menu_open} />

      <main class="overflow-hidden">
        <.hero_section />
        <.how_section />
        <.marquee_section />
        <.roles_section />
        <.features_section />
        <.why_section />
        <.cta_section />
      </main>

      <.site_footer />
    </div>
    """
  end

  attr :mobile_menu_open, :boolean, default: false

  def home_header(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 border-b bg-white border-border bg-bg/95 backdrop-blur">
      <nav class="mx-auto flex max-w-[1290px] items-center justify-between px-5 py-4 lg:py-5">
        <.brand_logo href={~p"/"} class="block   h-[20px] w-[70px]" />

        <div class="hidden items-center gap-8 lg:flex">
          <%= for item <- nav_links() do %>
            <a
              href={item.href}
              class="text-sm font-medium text-text-muted transition hover:text-accent"
            >
              {item.label}
            </a>
          <% end %>
        </div>

        <div class="hidden items-center gap-3 lg:flex">
          <.link
            href={~p"/users/log_in"}
            class="inline-flex items-center rounded-pill border border-border bg-surface px-5 py-2.5 text-sm font-medium text-text transition hover:border-border-strong hover:bg-surface-alt"
          >
            Log in
          </.link>
          <.link
            href={~p"/join/role"}
            class="inline-flex items-center rounded-pill bg-accent px-5 py-2.5 text-sm font-medium text-white transition hover:bg-accent-hover"
          >
            Get started
          </.link>
        </div>

        <button
          type="button"
          phx-click="toggle_mobile_menu"
          aria-expanded={to_string(@mobile_menu_open)}
          aria-controls="home-mobile-menu"
          class="inline-flex items-center justify-center rounded-pill border border-border bg-surface p-2.5 text-text transition hover:bg-surface-alt lg:hidden"
        >
          <span class="sr-only">Toggle navigation</span>
          <.icon name={if @mobile_menu_open, do: "hero-x-mark", else: "hero-bars-3"} class="h-5 w-5" />
        </button>
      </nav>

      <div
        :if={@mobile_menu_open}
        id="home-mobile-menu"
        class="border-t border-border bg-surface lg:hidden"
      >
        <div phx-click-away="close_mobile_menu" class="mx-auto max-w-[1290px] px-5 py-4">
          <div class="flex flex-col gap-2">
            <%= for item <- nav_links() do %>
              <a
                href={item.href}
                phx-click="close_mobile_menu"
                class="rounded-lg px-2 py-2 text-base font-medium text-text hover:bg-surface-alt"
              >
                {item.label}
              </a>
            <% end %>

            <div class="mt-3 flex flex-col gap-2">
              <.link
                href={~p"/join/role"}
                phx-click="close_mobile_menu"
                class="inline-flex items-center justify-center rounded-pill bg-accent px-5 py-3 font-medium text-white transition hover:bg-accent-hover"
              >
                Get started
              </.link>
              <.link
                href={~p"/users/log_in"}
                phx-click="close_mobile_menu"
                class="inline-flex items-center justify-center rounded-pill border border-border bg-surface px-5 py-3 font-medium text-text transition hover:bg-surface-alt"
              >
                Log in
              </.link>
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end

  def hero_section(assigns) do
    ~H"""
    <section class="relative min-h-screen overflow-hidden border-b border-border bg-surface lg:h-[100vh]">
      <div class="absolute inset-0 lg:hidden">
        <img
          src="https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1400&q=80"
          alt=""
          aria-hidden="true"
          class="absolute inset-y-0 right-[-18%] h-full w-[88%] object-cover object-[68%_center] opacity-95"
        />
        <div class="absolute inset-0 bg-[linear-gradient(90deg,rgba(255,255,255,0.99)_0%,rgba(255,255,255,0.98)_28%,rgba(255,255,255,0.94)_46%,rgba(255,255,255,0.76)_64%,rgba(255,255,255,0.36)_82%,rgba(255,255,255,0.08)_100%)]">
        </div>
        <div class="absolute inset-0 bg-gradient-to-b from-surface/18 via-transparent to-surface/70"></div>
      </div>

      <div class="absolute inset-y-0 right-0 hidden w-1/2 lg:block">
        <img
          src="https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1400&q=80"
          alt="Athlete training with a coach"
          class="h-[100vh] w-full object-cover"
        />
        <div class="absolute inset-0 bg-gradient-to-r from-surface via-surface/70 to-transparent">
        </div>
      </div>

      <div class="relative mx-auto grid max-w-[1290px] gap-14 px-5 py-16 sm:py-20 lg:grid-cols-[minmax(0,1fr)_360px] lg:py-24">
        <div class="max-w-[23rem] sm:max-w-[34rem] lg:max-w-[720px]">
          <p
            class="text-[3.6rem] font-black uppercase leading-none sm:text-[5.5rem] lg:text-[6.5rem]"
            style="color: transparent; -webkit-text-stroke: 2px var(--accent);"
          >
            Train Smarter
          </p>

          <h1 class="mt-3  text-3xl font-black leading-[1.02] text-text">
            Free AI Workout Plans Built Around Your Goal
          </h1>

          <p class="mt-8 max-w-2xl text-lg leading-8 text-text-muted">
            GymBro pairs athletes, trainers, and AI-built programming in one clean system.
            Choose your role, complete onboarding, get a structured plan, and log every
            workout as your progress compounds.
          </p>

          <div class="mt-10 flex flex-wrap gap-4">
            <.link
              href={~p"/join/role"}
              class="inline-flex items-center gap-2 rounded-pill bg-accent px-7 py-3.5 font-medium text-white transition hover:bg-accent-hover"
            >
              Start free <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>

            <.link
              href={~p"/users/log_in"}
              class="inline-flex items-center gap-2 rounded-pill border border-border bg-surface px-7 py-3.5 font-medium text-text transition hover:border-border-strong hover:bg-surface-alt"
            >
              Open the app <.icon name="hero-arrow-up-right" class="h-4 w-4" />
            </.link>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def how_section(assigns) do
    ~H"""
    <section id="how" class="py-24">
      <div class="mx-auto grid max-w-[1290px] items-center gap-16 px-5 lg:grid-cols-2">
        <div class="relative flex items-start gap-4">
          <img
            src="https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=1080&q=80"
            alt="Trainer coaching an athlete"
            class="h-[560px] w-[58%] rounded-lg object-cover"
          />
          <img
            src="https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=1080&q=80"
            alt="Athlete logging a workout"
            class="mt-20 h-[380px] w-[42%] rounded-lg object-cover"
          />

          <div class="absolute -bottom-6 left-1/2 flex -translate-x-1/2 flex-col items-center gap-2 rounded-lg border border-border bg-surface px-5 py-6 text-center shadow-md">
            <div class="text-4xl font-bold text-accent">10k+</div>
            <div class="text-lg font-medium text-text">Workouts logged</div>
          </div>
        </div>

        <div>
          <p class="type-label">How it works</p>
          <h2 class="mt-3 text-4xl font-bold uppercase leading-tight text-text lg:text-5xl">
            Your AI coach, built around you
          </h2>
          <p class="mt-8 text-lg leading-8 text-text-muted">
            GymBro starts with your role, your body stats, and your training goal. From
            there, the system generates a structured plan, guides your sessions day by day,
            and gives trainers room to adjust the program as you grow.
          </p>

          <div class="mt-10 space-y-4">
            <%= for step <- how_steps() do %>
              <div class="rounded-lg border border-border bg-surface p-5">
                <div class="flex items-start gap-4">
                  <span class="inline-flex h-10 w-10 items-center justify-center rounded-full bg-accent-soft font-semibold text-accent">
                    {step.number}
                  </span>
                  <div>
                    <h3 class="text-lg font-semibold text-text">{step.title}</h3>
                    <p class="mt-1 text-base leading-7 text-text-muted">{step.detail}</p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def marquee_section(assigns) do
    ~H"""
    <section class="border-y border-border bg-surface-alt py-6">
      <div class="overflow-hidden">
        <div class="flex w-max animate-[marquee_30s_linear_infinite] items-center gap-10 pr-10">
          <%= for label <- marquee_items() ++ marquee_items() do %>
            <div class="flex items-center gap-10">
              <span class="text-3xl font-bold uppercase text-accent lg:text-4xl">{label}</span>
              <span class="text-accent">&#9679;</span>
            </div>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  def roles_section(assigns) do
    ~H"""
    <section id="roles" class="py-24">
      <div class="mx-auto max-w-[1290px] px-5">
        <p class="type-label">Athletes and trainers</p>
        <h2 class="mt-3 text-4xl font-bold uppercase leading-tight text-text lg:text-5xl">
          One platform, two roles
        </h2>
        <p class="mt-4 max-w-3xl text-lg leading-8 text-text-muted">
          Whether you're chasing a personal best or coaching a roster of clients, GymBro
          gives each role the right tools at the right time, from AI-built plans to live
          session monitoring.
        </p>
      </div>

      <div class="mx-auto mt-12 flex max-w-[1290px] snap-x gap-6 overflow-x-auto px-5 pb-4 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        <%= for card <- role_cards() do %>
          <.role_card card={card} />
        <% end %>
      </div>
    </section>
    """
  end

  attr :card, :map, required: true

  def role_card(assigns) do
    ~H"""
    <article class="group relative h-[500px] w-[80%] flex-none snap-start overflow-hidden rounded-lg border border-border sm:w-[60%] lg:w-[31%]">
      <img
        src={@card.image}
        alt={@card.alt}
        class="h-full w-full object-cover transition duration-500 group-hover:scale-105"
      />
      <div class="absolute inset-0 bg-gradient-to-t from-[#18181B]/75 to-transparent"></div>
      <div class="absolute inset-x-0 bottom-0 p-6">
        <p
          class="text-3xl font-bold uppercase"
          style="color: transparent; -webkit-text-stroke: 1.5px var(--accent);"
        >
          {@card.kicker}
        </p>
        <h3 class="mt-2 text-2xl font-semibold text-white">{@card.title}</h3>
        <p class="mt-2 text-base leading-7 text-white/85">{@card.detail}</p>
      </div>
    </article>
    """
  end

  def features_section(assigns) do
    ~H"""
    <section id="features" class="py-24">
      <div class="mx-auto max-w-[1290px] px-5">
        <div class="text-center">
          <p class="type-label">Platform features</p>
          <h2 class="mt-3 text-4xl font-bold uppercase leading-tight text-text lg:text-5xl">
            Everything GymBro does
          </h2>
          <p class="mx-auto mt-4 max-w-3xl text-lg leading-8 text-text-muted">
            From first sign-up to long-term progress, GymBro brings coaching, AI, and
            training data into one connected product.
          </p>
        </div>

        <div class="mt-16 grid gap-8 sm:grid-cols-2 lg:grid-cols-3">
          <%= for card <- feature_cards() do %>
            <article class="overflow-hidden rounded-lg border border-border bg-surface transition hover:-translate-y-1 hover:border-border-strong">
              <img src={card.image} alt={card.alt} class="h-56 w-full object-cover" />
              <div class="p-7">
                <div class="text-xl font-semibold text-text">{card.title}</div>
                <p class="mt-3 text-base leading-7 text-text-muted">{card.detail}</p>
              </div>
            </article>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  def why_section(assigns) do
    ~H"""
    <section class="py-24">
      <div class="mx-auto max-w-[1290px] px-5">
        <div class="relative">
          <div
            class="pointer-events-none absolute inset-x-0 top-0 text-center text-[110px] font-black leading-none opacity-10 sm:text-[170px]"
            style="color: transparent; -webkit-text-stroke: 2px var(--border-strong);"
          >
            GYMBRO
          </div>

          <div class="relative grid gap-8 pt-20 sm:grid-cols-2 lg:grid-cols-4">
            <%= for item <- why_items() do %>
              <article class="rounded-lg border border-border bg-surface p-6">
                <span class="inline-flex h-14 w-14 items-center justify-center rounded-full bg-accent-soft text-accent">
                  <.icon name={item.icon} class="h-7 w-7" />
                </span>
                <h3 class="mt-6 text-xl font-semibold text-text">{item.title}</h3>
                <p class="mt-3 text-base leading-7 text-text-muted">{item.detail}</p>
              </article>
            <% end %>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def cta_section(assigns) do
    ~H"""
    <section class="relative overflow-hidden border-y border-border bg-text py-24 text-white">
      <img
        src="https://images.unsplash.com/photo-1517344884509-a0c97ec11bcc?w=1400&q=80"
        alt=""
        aria-hidden="true"
        class="absolute inset-0 h-full w-full object-cover opacity-20"
      />

      <div class="relative mx-auto max-w-[1290px] px-5">
        <div class="max-w-2xl">
          <p class="type-label !text-white/60">Start here</p>
          <h2 class="mt-3 text-4xl font-bold uppercase leading-tight text-white lg:text-5xl">
            Start training smarter today
          </h2>
          <p class="mt-6 text-lg leading-8 text-white/80">
            Get a personalized plan, stay consistent, and track real progress. Join GymBro
            as an athlete or bring your coaching practice on board.
          </p>

          <div class="mt-10 flex flex-wrap gap-4">
            <.link
              href={~p"/join/role"}
              class="inline-flex items-center gap-2 rounded-pill bg-accent px-7 py-3.5 font-medium text-white transition hover:bg-accent-hover"
            >
              Join as athlete <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>

            <.link
              href={~p"/join/role"}
              class="inline-flex items-center gap-2 rounded-pill border border-white/20 px-7 py-3.5 font-medium text-white transition hover:bg-white/10"
            >
              Become a trainer <.icon name="hero-arrow-right" class="h-4 w-4" />
            </.link>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def site_footer(assigns) do
    ~H"""
    <footer id="footer" class="border-t border-border">
      <div class="mx-auto max-w-[1290px] px-5 py-16">
        <div class="grid gap-10 overflow-hidden rounded-[24px] border border-border bg-surface-alt p-8 md:grid-cols-2 md:p-12">
          <div class="flex flex-col gap-5">
            <p class="type-label">Newsletter</p>
            <h2 class="text-4xl font-bold uppercase leading-tight text-text">
              Train smarter, stay consistent
            </h2>
            <p class="text-lg leading-8 text-text-muted">
              Get training tips, product updates, and progress stories from the GymBro
              community straight to your inbox.
            </p>

            <form class="relative mt-2 max-w-md" onsubmit="return false">
              <input
                type="email"
                placeholder="you@email.com"
                required
                class="h-14 w-full rounded border border-border bg-surface pl-5 pr-16 text-text outline-none transition focus:border-border-strong focus:ring-4 focus:ring-accent/10"
              />
              <button
                type="submit"
                aria-label="Subscribe"
                class="absolute right-2 top-1/2 flex h-10 w-10 -translate-y-1/2 items-center justify-center rounded-full bg-accent text-white transition hover:bg-accent-hover"
              >
                <.icon name="hero-arrow-right" class="h-4 w-4" />
              </button>
            </form>
          </div>

          <img
            src="https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=1080&q=80"
            alt="Athlete training"
            class="hidden h-full w-full rounded-[20px] object-cover md:block"
          />
        </div>

        <div class="mt-16 grid gap-12 md:grid-cols-2 lg:grid-cols-4">
          <div class="flex flex-col gap-6">
            <.brand_logo href={~p"/"} class="block w-[180px]" img_class="h-auto w-full" />

            <div class="space-y-3 text-base leading-7 text-text-muted">
              <p>123 Training Way, Suite 400, Austin, Texas 78701</p>
              <p>
                <a href="mailto:hello@gymbro.app" class="transition hover:text-accent">
                  hello@gymbro.app
                </a>
              </p>
              <p>
                <a href="tel:+15125550199" class="transition hover:text-accent">
                  (512) 555-0199
                </a>
              </p>
            </div>
          </div>

          <div>
            <h3 class="text-xl font-bold uppercase text-text">Product</h3>
            <div class="mt-6 flex flex-col gap-3">
              <%= for item <- nav_links() do %>
                <a href={item.href} class="text-text-muted transition hover:text-accent">
                  {item.label}
                </a>
              <% end %>
            </div>
          </div>

          <div>
            <h3 class="text-xl font-bold uppercase text-text">Support hours</h3>
            <div class="mt-6 space-y-5 text-text-muted">
              <div>
                <div class="font-medium text-text">Monday to Friday</div>
                <p>8:00 AM to 8:00 PM</p>
              </div>
              <div>
                <div class="font-medium text-text">Saturday</div>
                <p>10:00 AM to 4:00 PM</p>
              </div>
            </div>
          </div>

          <div>
            <h3 class="text-xl font-bold uppercase text-text">Start now</h3>
            <p class="mt-6 text-base leading-7 text-text-muted">
              Pick your role, get your plan, and bring your workouts into one place.
            </p>
            <div class="mt-6 flex flex-col gap-3">
              <.link
                href={~p"/join/role"}
                class="inline-flex items-center justify-center rounded-pill bg-accent px-5 py-3 font-medium text-white transition hover:bg-accent-hover"
              >
                Join GymBro
              </.link>
              <.link
                href={~p"/users/log_in"}
                class="inline-flex items-center justify-center rounded-pill border border-border bg-surface px-5 py-3 font-medium text-text transition hover:bg-surface-alt"
              >
                Log in
              </.link>
            </div>
          </div>
        </div>
      </div>

      <div class="border-t border-border">
        <div class="mx-auto flex max-w-[1290px] flex-wrap items-center gap-3 px-5 py-8 text-sm text-text-muted">
          <span>Copyright © 2026 GymBro</span>
          <span class="text-border-strong">|</span>
          <a href="#footer" class="transition hover:text-accent">Privacy Policy</a>
          <span class="text-border-strong">|</span>
          <a href="#footer" class="transition hover:text-accent">Terms of Service</a>
        </div>
        <div class="mx-auto max-w-[1290px] px-5 pb-8 text-sm text-text-muted">
          Built by
          <a
            href="https://michaelmunavu.com"
            target="_blank"
            rel="noopener noreferrer"
            class="font-medium text-text transition hover:text-accent"
          >
            Michael Munavu
          </a>
          (<a
            href="https://michaelmunavu.com"
            target="_blank"
            rel="noopener noreferrer"
            class="transition hover:text-accent"
          >michaelmunavu.com</a>)
        </div>
      </div>
    </footer>
    """
  end

  defp nav_links do
    [
      %{label: "How it Works", href: "#how"},
      %{label: "Roles", href: "#roles"},
      %{label: "Features", href: "#features"},
      %{label: "Contact", href: "#footer"}
    ]
  end

  defp how_steps do
    [
      %{
        number: "1",
        title: "Choose your role",
        detail:
          "Start as an athlete or trainer so GymBro can shape the right workflow from day one."
      },
      %{
        number: "2",
        title: "Complete onboarding",
        detail:
          "Capture body stats, training goals, preferred schedule, and equipment in a few quick steps."
      },
      %{
        number: "3",
        title: "Train and coach inside the app",
        detail:
          "Athletes log sessions while trainers monitor activity, invite clients, and refine plans."
      }
    ]
  end

  defp marquee_items do
    [
      "AI Workout Plans",
      "Live Logging",
      "Progress Tracking",
      "Trainer Dashboard",
      "Body Stats",
      "Coach and Client"
    ]
  end

  defp role_cards do
    [
      %{
        image: "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1080&q=80",
        alt: "Personalized training plans",
        kicker: "Athlete Flow",
        title: "Personalized Plans",
        detail: "Receive a structured workout plan based on your goal, schedule, and equipment."
      },
      %{
        image: "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=1080&q=80",
        alt: "Live workout logging",
        kicker: "Workout Flow",
        title: "Live Workout Logging",
        detail: "Track every set in real time and keep sessions organized from warm-up to finish."
      },
      %{
        image: "https://images.unsplash.com/photo-1518611012118-696072aa579a?w=1080&q=80",
        alt: "Progress tracking",
        kicker: "Body Stats",
        title: "Progress Tracking",
        detail: "Log weight, photos, and training data so improvements are visible over time."
      },
      %{
        image: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=1080&q=80",
        alt: "Trainer coaching",
        kicker: "Coach View",
        title: "Trainer Coaching",
        detail:
          "Invite clients, monitor live activity, and adjust exercises without leaving the platform."
      }
    ]
  end

  defp feature_cards do
    [
      %{
        image: "https://images.unsplash.com/photo-1556157382-97eda2d62296?w=1080&q=80",
        alt: "Role-based access",
        title: "Role-Based Access",
        detail:
          "Secure accounts and permissions for athletes and trainers, with the right tools surfaced for each role."
      },
      %{
        image: "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=1080&q=80",
        alt: "Guided onboarding",
        title: "Guided Onboarding",
        detail:
          "Capture body stats, training goals, and preferences in minutes so your plan starts on day one."
      },
      %{
        image: "https://images.unsplash.com/photo-1517344884509-a0c97ec11bcc?w=1080&q=80",
        alt: "AI workout plans",
        title: "AI Workout Plans",
        detail:
          "Get a structured training program generated from your profile, with daily targets you can actually follow."
      },
      %{
        image: "https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=1080&q=80",
        alt: "Live workout logging",
        title: "Live Workout Logging",
        detail:
          "Track sets, reps, weight, and rest time as you train, with sessions saved straight to your history."
      },
      %{
        image: "https://images.unsplash.com/photo-1538805060514-97d9cc17730c?w=1080&q=80",
        alt: "Progress tracking",
        title: "Progress Tracking",
        detail:
          "Log body weight and check-in photos, then watch trends and personal records build over time."
      },
      %{
        image: "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=1080&q=80",
        alt: "Trainer dashboard",
        title: "Trainer Dashboard",
        detail:
          "Invite clients, manage your roster, override exercises, and review analytics across everyone you coach."
      }
    ]
  end

  defp why_items do
    [
      %{
        icon: "hero-cpu-chip",
        title: "AI-Powered Plans",
        detail:
          "Programs are generated from your real profile and adapt as your stats and goals evolve."
      },
      %{
        icon: "hero-bolt",
        title: "Stay Consistent",
        detail:
          "Daily targets and live logging keep athletes showing up and finishing every session."
      },
      %{
        icon: "hero-chart-bar-square",
        title: "Real Progress Data",
        detail: "Body weight, photos, and lifting trends turn effort into measurable results."
      },
      %{
        icon: "hero-user-group",
        title: "Coach Connection",
        detail:
          "Trainers can review activity, adjust plans, and support athletes without extra tooling."
      }
    ]
  end
end
