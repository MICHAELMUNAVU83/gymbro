defmodule GymBroWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for GymBro's light, minimalistic system.
  """
  use Phoenix.Component
  use Gettext, backend: GymBroWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-[rgba(20,20,23,0.32)] transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="w-full max-w-2xl">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="relative hidden rounded-lg bg-surface p-8 shadow-md ring-1 ring-border transition"
            >
              <div class="absolute top-4 right-4">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="rounded-sm p-2 text-text-subtle hover:text-text hover:bg-surface-alt"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices as a top toast anchored under the top bar.
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :auto_dismiss, :boolean, default: true
  attr :dismiss_after, :integer, default: 3_000
  attr :show_on_mount, :boolean, default: true
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-mounted={@show_on_mount && show("##{@id}")}
      phx-hook={@auto_dismiss && "AutoDismiss"}
      data-dismiss-after={@auto_dismiss && @dismiss_after}
      role="alert"
      class={[
        "app-toast fixed inset-x-0 top-4 z-50 mx-auto flex w-[min(calc(100%-2rem),28rem)] items-start gap-3 rounded border bg-surface px-4 py-3 shadow-md",
        @kind == :info && "border-border",
        @kind == :error && "border-accent"
      ]}
      {@rest}
    >
      <.icon :if={@kind == :info} name="hero-check-circle" class="h-5 w-5 flex-none text-success" />
      <.icon
        :if={@kind == :error}
        name="hero-exclamation-circle"
        class="h-5 w-5 flex-none text-accent"
      />
      <div class="min-w-0 flex-1 text-sm leading-5 text-text">
        <p :if={@title} class="font-semibold">{@title}</p>
        <p class={@title && "mt-1 text-text-muted"}>{msg}</p>
      </div>
      <button
        type="button"
        class="flex-none text-text-subtle hover:text-text"
        aria-label={gettext("close")}
      >
        <.icon name="hero-x-mark" class="h-4 w-4" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("Success")} flash={@flash} />
      <.flash kind={:error} title={gettext("Something went wrong")} flash={@flash} />
    </div>
    """
  end

  @doc """
  Renders a card primitive.
  """
  attr :class, :string, default: nil
  attr :quiet, :boolean, default: false
  attr :accent, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div
      class={[
        "gb-card",
        @quiet && "gb-card--quiet",
        @accent && "gb-card--accent",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the shared GymBro logo image, optionally as a link.
  """
  attr :href, :string, default: nil
  attr :class, :string, default: nil
  attr :img_class, :string, default: "h-auto w-full"
  attr :alt, :string, default: "GymBro"

  def brand_logo(%{href: href} = assigns) when is_binary(href) do
    ~H"""
    <.link href={@href} class={@class} aria-label="GymBro home">
      <img src="/images/logo.png" alt={@alt} class={@img_class} />
    </.link>
    """
  end

  def brand_logo(assigns) do
    ~H"""
    <div class={@class}>
      <img src="/images/logo.png" alt={@alt} class={@img_class} />
    </div>
    """
  end

  @doc """
  Section heading with a red leading bar and optional icon.

  ## Example

      <.section_head icon="hero-fire-mini">Next workout</.section_head>
  """
  attr :icon, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def section_head(assigns) do
    ~H"""
    <div class={["gb-section-head", @class]}>
      <.icon :if={@icon} name={@icon} class="gb-section-head__icon" />
      <p class="type-label" style="color: var(--text); letter-spacing: 0.08em;">
        {render_slot(@inner_block)}
      </p>
    </div>
    """
  end

  @doc """
  A horizontal stat row separated by hairlines.

  ## Examples

      <.stat_row>
        <:item label="Duration">58 min</:item>
        <:item label="Exercises">4</:item>
        <:item label="Status">Ready</:item>
      </.stat_row>
  """
  attr :class, :string, default: nil

  slot :item, required: true do
    attr :label, :string, required: true
    attr :icon, :string
  end

  def stat_row(assigns) do
    cols = length(assigns.item)
    assigns = assign(assigns, :cols, cols)

    ~H"""
    <div class={["gb-stat-row", @class]} style={"--stat-cols: #{@cols}"}>
      <div :for={item <- @item}>
        <p class="type-label inline-flex items-center gap-1.5">
          <.icon :if={item[:icon]} name={item[:icon]} class="h-3.5 w-3.5 text-accent" />
          {item.label}
        </p>
        <p class="mt-1 type-mono-stat">{render_slot(item)}</p>
      </div>
    </div>
    """
  end

  @doc """
  Accent callout / trainer notes box.
  """
  attr :label, :string, default: nil
  attr :class, :string, default: nil
  attr :quiet, :boolean, default: false
  slot :inner_block, required: true

  def callout(assigns) do
    ~H"""
    <aside class={["gb-callout", @quiet && "gb-callout--quiet", @class]}>
      <p :if={@label} class="type-label" style={if @quiet, do: nil, else: "color: var(--accent)"}>
        {@label}
      </p>
      <div class={["type-body", @label && "mt-1"]}>
        {render_slot(@inner_block)}
      </div>
    </aside>
    """
  end

  @doc """
  Renders a button.

  Variants: `primary` (default), `secondary`, `ghost`, `destructive`.
  Sizes: `sm`, `md` (default), `lg`.
  """
  attr :type, :string, default: nil
  attr :variant, :string, default: "primary", values: ~w(primary secondary ghost destructive)
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :block, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "gb-btn",
        "gb-btn--#{@variant}",
        @size == "sm" && "gb-btn--sm",
        @size == "lg" && "gb-btn--lg",
        @block && "gb-btn--block",
        "phx-submit-loading:opacity-75",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :stat, :boolean, default: false, doc: "render a numeric stat-style input"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div>
      <label class="flex items-center gap-3 text-sm leading-6 text-text">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="h-4 w-4 rounded border-border text-accent focus:ring-2 focus:ring-accent focus:ring-offset-0"
          {@rest}
        />
        {@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class={["gb-input mt-2", @errors != [] && "gb-input--error"]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "gb-input mt-2 min-h-[6rem]",
          @errors != [] && "gb-input--error"
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "gb-input mt-2",
          @stat && "gb-input--stat",
          @errors != [] && "gb-input--error"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="type-label">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-2 flex items-center gap-2 text-sm leading-5 text-accent">
      <.icon name="hero-exclamation-circle-mini" class="h-4 w-4 flex-none" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-start justify-between gap-6", @class]}>
      <div>
        <h1 class="type-h1">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 type-body-sm">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto">
      <table class="w-full text-left text-sm">
        <thead class="text-text-subtle">
          <tr class="border-b border-border">
            <th :for={col <- @col} class="px-3 py-3 font-medium type-label">{col[:label]}</th>
            <th :if={@action != []} class="px-3 py-3">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="text-text"
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="border-b border-border hover:bg-surface-alt"
          >
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["px-3 py-3", @row_click && "cursor-pointer", i == 0 && "font-medium"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="px-3 py-3 text-right">
              <span :for={action <- @action} class="ml-3 font-medium text-text hover:text-accent">
                {render_slot(action, @row_item.(row))}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="divide-y divide-border">
      <div :for={item <- @item} class="flex gap-6 py-3 text-sm">
        <dt class="w-1/4 flex-none type-label">{item.title}</dt>
        <dd class="type-body">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders a back navigation link.
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="inline-flex items-center gap-1 text-sm font-medium text-text-muted hover:text-text"
    >
      <.icon name="hero-arrow-left-mini" class="h-4 w-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 180,
      transition:
        {"transition-all transform ease-out duration-200", "opacity-0 -translate-y-2",
         "opacity-100 translate-y-0"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 150,
      transition:
        {"transition-all transform ease-in duration-150", "opacity-100 translate-y-0",
         "opacity-0 -translate-y-2"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-all transform ease-out duration-200", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-150", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(GymBroWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(GymBroWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Renders a simple form (kept for back-compat with auth controllers).
  """
  attr :for, :any, required: true, doc: "the data structure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="mt-8 space-y-5">
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="flex items-center justify-between gap-4">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end
end
