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
        <.pricing_section />
        <.why_section />
        <.cta_section />
        <.blog_section />
      </main>

      <.site_footer />
    </div>
    """
  end

  attr :mobile_menu_open, :boolean, default: false

  def home_header(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 border-b bg-white border-border bg-bg/95 backdrop-blur">
      <nav class="mx-auto flex max-w-[1290px] items-center justify-between px-5 py-5">
        <.link href={~p"/"} class="flex items-center gap-3" aria-label="GymBro home">
          <span class="inline-flex h-10 w-10 items-center justify-center rounded-full border border-accent/20 bg-accent-soft text-accent">
            <svg
              class="h-5 w-5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <path d="M6.5 9v6M9 7.5v9M15 7.5v9M17.5 9v6M9 12h6" />
            </svg>
          </span>
          <span class="text-xl font-extrabold uppercase tracking-tight text-text">
            Gym<span class="text-accent">Bro</span>
          </span>
        </.link>

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
          class="inline-flex items-center justify-center rounded-pill border border-border bg-surface p-3 text-text lg:hidden"
        >
          <span class="sr-only">Toggle navigation</span>
          <.icon name="hero-bars-3" class="h-5 w-5" />
        </button>
      </nav>

      <div
        :if={@mobile_menu_open}
        id="home-mobile-menu"
        class="border-t border-border bg-surface lg:hidden"
      >
        <div class="mx-auto max-w-[1290px] px-5 py-4">
          <div class="flex flex-col gap-2">
            <%= for item <- nav_links() do %>
              <a
                href={item.href}
                class="rounded-lg px-2 py-2 text-base font-medium text-text hover:bg-surface-alt"
              >
                {item.label}
              </a>
            <% end %>

            <div class="mt-3 flex flex-col gap-2">
              <.link
                href={~p"/join/role"}
                class="inline-flex items-center justify-center rounded-pill bg-accent px-5 py-3 font-medium text-white transition hover:bg-accent-hover"
              >
                Get started
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
    </header>
    """
  end

  def hero_section(assigns) do
    ~H"""
    <section class="relative h-[100vh] overflow-hidden border-b border-border bg-surface">
      <div class="absolute inset-y-0 right-0 hidden w-1/2 lg:block">
        <img
          src="https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1400&q=80"
          alt="Athlete training with a coach"
          class="h-[100vh] w-full object-cover"
        />
        <div class="absolute inset-0 bg-gradient-to-r from-surface via-surface/70 to-transparent">
        </div>
      </div>

      <div class="relative mx-auto grid max-w-[1290px] gap-14 px-5 py-16 lg:grid-cols-[minmax(0,1fr)_360px] lg:py-24">
        <div class="max-w-[720px]">
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

  def pricing_section(assigns) do
    ~H"""
    <section id="pricing" class="border-y border-border bg-surface-alt py-24">
      <div class="mx-auto max-w-[1290px] px-5">
        <div class="max-w-3xl">
          <p class="type-label">Plans</p>
          <h2 class="mt-3 text-4xl font-bold uppercase leading-tight text-text lg:text-5xl">
            Choose your GymBro plan
          </h2>
          <p class="mt-6 text-lg leading-8 text-text-muted">
            Start free as an athlete, upgrade when you want deeper analytics, or bring your
            whole coaching business onto GymBro.
          </p>
        </div>

        <div class="mt-14 grid gap-6 lg:grid-cols-4">
          <%= for card <- pricing_cards() do %>
            <.pricing_card card={card} />
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  attr :card, :map, required: true

  def pricing_card(assigns) do
    ~H"""
    <article class={[
      "flex h-full flex-col rounded-lg border bg-surface p-8",
      if(@card.highlight, do: "border-accent shadow-md", else: "border-border")
    ]}>
      <div class="flex items-start justify-between gap-3">
        <div>
          <h3 class="text-xl font-semibold text-text">{@card.title}</h3>
          <p class="mt-2 text-sm leading-6 text-text-muted">{@card.description}</p>
        </div>
        <span
          :if={@card.badge}
          class="rounded-pill bg-accent-soft px-3 py-1 text-xs font-semibold uppercase tracking-wide text-accent"
        >
          {@card.badge}
        </span>
      </div>

      <div class="mt-8 flex items-end gap-2">
        <span class="text-5xl font-bold leading-none text-text">{@card.price}</span>
        <span class="pb-1 text-base text-text-muted">{@card.period}</span>
      </div>

      <a
        href={@card.href}
        class={[
          "mt-8 inline-flex items-center justify-center rounded-pill px-6 py-3 font-medium transition",
          if(@card.highlight,
            do: "bg-accent text-white hover:bg-accent-hover",
            else: "border border-border bg-surface text-text hover:bg-surface-alt"
          )
        ]}
      >
        {@card.cta}
      </a>

      <ul class="mt-8 space-y-3 text-sm leading-6 text-text-muted">
        <%= for feature <- @card.features do %>
          <li class="flex items-start gap-3">
            <span class="mt-0.5 text-accent">&#10003;</span>
            <span>{feature}</span>
          </li>
        <% end %>
      </ul>
    </article>
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

  def blog_section(assigns) do
    ~H"""
    <section id="blog" class="py-24">
      <div class="mx-auto max-w-[1290px] px-5">
        <div class="text-center">
          <p class="type-label">Resources</p>
          <h2 class="mt-3 text-4xl font-bold uppercase leading-tight text-text lg:text-5xl">
            From the GymBro blog
          </h2>
        </div>

        <div class="mt-16 flex flex-col gap-8">
          <%= for article <- blog_articles() do %>
            <.blog_article article={article} />
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  attr :article, :map, required: true

  def blog_article(assigns) do
    ~H"""
    <article class="flex flex-col gap-8 overflow-hidden rounded-lg border border-border bg-surface p-6 md:flex-row md:items-center md:p-10">
      <img
        src={@article.image}
        alt={@article.alt}
        class="h-56 w-full rounded-lg object-cover md:h-44 md:w-72"
      />

      <div class="flex-1">
        <h3 class="text-2xl font-bold text-text">{@article.title}</h3>
        <p class="mt-3 text-base leading-7 text-text-muted">{@article.detail}</p>
      </div>

      <a
        href="#footer"
        class="inline-flex items-center gap-2 self-start rounded-pill border border-border px-6 py-3 font-medium text-text transition hover:bg-surface-alt"
      >
        Read more <.icon name="hero-arrow-up-right" class="h-4 w-4" />
      </a>
    </article>
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
            <.link href={~p"/"} class="flex items-center gap-3">
              <span class="inline-flex h-10 w-10 items-center justify-center rounded-full border border-accent/20 bg-accent-soft text-accent">
                <svg
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  aria-hidden="true"
                >
                  <path d="M6.5 9v6M9 7.5v9M15 7.5v9M17.5 9v6M9 12h6" />
                </svg>
              </span>
              <span class="text-xl font-extrabold uppercase text-text">
                Gym<span class="text-accent">Bro</span>
              </span>
            </.link>

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
      </div>
    </footer>
    """
  end

  defp nav_links do
    [
      %{label: "How it Works", href: "#how"},
      %{label: "Roles", href: "#roles"},
      %{label: "Features", href: "#features"},
      %{label: "Pricing", href: "#pricing"},
      %{label: "Blog", href: "#blog"},
      %{label: "Contact", href: "#footer"}
    ]
  end

  defp hero_stats do
    [
      %{
        label: "Athletes",
        value: "Free start",
        detail: "Join free, onboard fast, train with structure."
      },
      %{
        label: "Trainers",
        value: "Client view",
        detail: "Monitor progress, adjust plans, stay connected."
      },
      %{
        label: "Plans",
        value: "AI built",
        detail: "Structured blocks generated from goals and preferences."
      }
    ]
  end

  defp hero_bullets do
    [
      %{
        icon: "hero-cpu-chip",
        title: "AI program builder",
        detail: "Generate a practical training block from body stats, goals, and equipment."
      },
      %{
        icon: "hero-bolt",
        title: "Live workout logging",
        detail: "Track sets, reps, weight, and rest time during every session."
      },
      %{
        icon: "hero-chart-bar",
        title: "Progress tracking",
        detail: "Review weight trends, photos, and training consistency in one place."
      }
    ]
  end

  defp hero_roles do
    [
      %{initials: "AI", label: "Planner", class: "bg-accent text-white"},
      %{initials: "AT", label: "Athlete", class: "bg-surface text-text border border-border"},
      %{initials: "TR", label: "Trainer", class: "bg-surface-alt text-text"}
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

  defp pricing_cards do
    [
      %{
        title: "Athlete",
        description: "Everything needed to start training with structure.",
        price: "$0",
        period: "/ month",
        cta: "Get started",
        href: ~p"/join/role",
        highlight: false,
        badge: nil,
        features: [
          "AI-generated starter plan",
          "Workout and set logging",
          "Body weight tracking",
          "Daily training targets"
        ]
      },
      %{
        title: "Pro Athlete",
        description: "Deeper visibility for athletes who want more insight.",
        price: "$15",
        period: "/ month",
        cta: "Upgrade",
        href: "#footer",
        highlight: false,
        badge: nil,
        features: [
          "Adaptive AI plan refreshes",
          "Check-in photos and trends",
          "Advanced progress analytics",
          "Priority support"
        ]
      },
      %{
        title: "Coach",
        description: "Built for trainers managing and coaching active clients.",
        price: "$39",
        period: "/ month",
        cta: "Join as coach",
        href: ~p"/join/role",
        highlight: true,
        badge: "Popular",
        features: [
          "Up to 25 clients",
          "Invitation and linking flow",
          "Exercise overrides",
          "Live session monitoring"
        ]
      },
      %{
        title: "Team / Studio",
        description: "For larger coaching operations and multi-trainer teams.",
        price: "$99",
        period: "/ month",
        cta: "Contact sales",
        href: "mailto:hello@gymbro.app",
        highlight: false,
        badge: nil,
        features: [
          "Unlimited clients",
          "Multiple trainer seats",
          "Cross-client analytics",
          "Dedicated onboarding"
        ]
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

  defp blog_articles do
    [
      %{
        image: "https://images.unsplash.com/photo-1517344884509-a0c97ec11bcc?w=800&q=80",
        alt: "How AI builds your training split",
        title: "How AI Builds Your Perfect Training Split",
        detail:
          "A look under the hood at how GymBro turns your body stats, goals, and preferences into a structured program you can actually follow."
      },
      %{
        image: "https://images.unsplash.com/photo-1538805060514-97d9cc17730c?w=800&q=80",
        alt: "Logging habits that accelerate progress",
        title: "5 Logging Habits That Accelerate Progress",
        detail:
          "Tracking sets, reps, weight, and rest time consistently is one of the fastest ways to break plateaus."
      },
      %{
        image: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&q=80",
        alt: "Coaching clients remotely",
        title: "Coaching Clients Remotely with GymBro",
        detail:
          "From inviting clients to monitoring live sessions and reviewing analytics, here's how coaches run a remote practice on GymBro."
      }
    ]
  end
end
