defmodule GymBroWeb.Athlete.BodyStatsLive do
  use GymBroWeb, :live_view

  alias GymBro.BodyStats
  alias GymBro.BodyStats.{BodyWeightLog, CheckinImage}
  alias GymBro.{Onboarding, Profiles, Uploads}

  @chart_width 320.0
  @chart_height 160.0
  @chart_padding 16.0

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case Onboarding.next_path(current_user) do
      "/" ->
        socket =
          socket
          |> allow_upload(:progress_image, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)
          |> assign_body_stats(current_user)
          |> assign_forms()
          |> assign(:active_nav, :body_stats)
          |> assign(:page_title, "Body Stats")

        {:ok, socket}

      path ->
        {:ok, push_navigate(socket, to: path), layout: false}
    end
  end

  @impl true
  def handle_event("save_weight", %{"body_weight_log" => params}, socket) do
    current_user = socket.assigns.current_user

    case BodyStats.create_body_weight_log(Map.put(params, "user_id", current_user.id)) do
      {:ok, _log} ->
        {:noreply,
         socket
         |> assign_body_stats(current_user)
         |> assign_forms()
         |> put_flash(:info, "Weight log added.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :weight_form, to_form(changeset))}
    end
  end

  def handle_event("save_progress", %{"progress_photo" => params}, socket) do
    save_image(
      socket,
      :progress_image,
      params,
      "progress",
      :progress_form,
      "Progress photo uploaded."
    )
  end

  def handle_event("validate_progress", %{"progress_photo" => params}, socket) do
    {:noreply, assign_image_form(socket, :progress_form, params, "progress", :progress_photo)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="gb-grid">
      <div class="gb-grid__main space-y-8">
        <header>
          <p class="type-label">Body stats</p>
          <h1 class="mt-2 type-h1">Track the proof, not just the plan.</h1>
          <p class="mt-3 max-w-[60ch] type-body text-text-muted">
            Log scale weight, upload check-ins, and keep a clean visual record of progress over time.
          </p>
        </header>

        <section>
          <header class="flex items-end justify-between">
            <div>
              <p class="type-label">Weight trend</p>
              <h2 class="mt-1 type-h2">{format_weight(@latest_weight_kg)}</h2>
            </div>
            <p class="type-body-sm">
              {format_weight(@weight_chart.min_weight)} – {format_weight(@weight_chart.max_weight)}
            </p>
          </header>

          <div class="mt-4">
            <svg viewBox="0 0 320 160" class="h-44 w-full">
              <line x1="16" y1="144" x2="304" y2="144" stroke="var(--border)" stroke-width="1" />
              <polyline
                points={@weight_chart.polyline_points}
                fill="none"
                stroke="var(--accent)"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                opacity={if length(@weight_chart.points) > 1, do: "1", else: "0"}
              />
              <circle
                :for={point <- @weight_chart.points}
                cx={point.x}
                cy={point.y}
                r="3"
                fill="var(--accent)"
              />
              <text
                :for={point <- @weight_chart.points}
                x={point.x}
                y="156"
                text-anchor="middle"
                fill="var(--text-subtle)"
                class="text-[10px]"
              >
                {point.label}
              </text>
            </svg>
          </div>
        </section>

        <hr class="gb-divider" />

        <section>
          <header class="flex items-end justify-between">
            <div>
              <p class="type-label">Weight log</p>
              <h2 class="mt-1 type-h2">Add today's weigh-in</h2>
            </div>
            <p class="type-body-sm">{length(@weight_logs)} total entries</p>
          </header>

          <.form
            id="weight-log-form"
            for={@weight_form}
            phx-submit="save_weight"
            class="mt-4 space-y-3"
          >
            <div class="grid grid-cols-2 gap-3">
              <.input
                field={@weight_form[:weight_kg]}
                type="number"
                step="0.1"
                label="Weight kg"
                stat
              />
              <.input field={@weight_form[:logged_at]} type="date" label="Date" />
            </div>
            <.input
              field={@weight_form[:notes]}
              type="text"
              label="Notes"
              placeholder="Morning weigh-in, after cardio, etc."
            />
            <button type="submit" class="gb-btn gb-btn--primary gb-btn--block">
              Save weight
            </button>
          </.form>

          <ul :if={@weight_logs != []} class="mt-6 divide-y divide-border border-y border-border">
            <li
              :for={log <- Enum.take(@weight_logs, 5)}
              class="flex items-center justify-between py-3 text-sm"
            >
              <div>
                <p class="font-medium text-text">{format_weight(log.weight_kg)}</p>
                <p class="type-body-sm">{Calendar.strftime(log.logged_at, "%b %-d, %Y")}</p>
              </div>
              <p class="max-w-[18ch] text-right type-body-sm">{log.notes || "—"}</p>
            </li>
          </ul>
        </section>

        <hr class="gb-divider" />

        <section>
          <header>
            <p class="type-label">Progress photo upload</p>
            <h2 class="mt-1 type-h2">Save milestone photos</h2>
          </header>

          <.form
            id="progress-upload-form"
            for={@progress_form}
            phx-change="validate_progress"
            phx-submit="save_progress"
            class="mt-4 space-y-3"
          >
            <.input field={@progress_form[:logged_at]} type="date" label="Date" />
            <.input
              field={@progress_form[:notes]}
              type="text"
              label="Notes"
              placeholder="Week 4 comparison, posing update, etc."
            />
            <div>
              <span class="type-label">Image</span>
              <div class="mt-2 rounded border border-dashed border-border bg-surface-alt p-4">
                <.live_file_input
                  upload={@uploads.progress_image}
                  class="block w-full text-sm text-text-muted file:mr-3 file:rounded file:border-0 file:bg-text file:px-3 file:py-2 file:text-sm file:font-semibold file:text-white"
                />
              </div>
            </div>

            <p :if={@uploads.progress_image.entries != []} class="type-body-sm">
              {upload_entry_name(@uploads.progress_image.entries)}
            </p>

            <button type="submit" class="gb-btn gb-btn--primary gb-btn--block">
              Upload progress photo
            </button>
          </.form>
        </section>

        <hr class="gb-divider" />

        <section>
          <header>
            <p class="type-label">Recent check-ins</p>
            <h2 class="mt-1 type-h2">Photo timeline</h2>
          </header>

          <div class="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-3">
            <figure
              :for={image <- Enum.take(@checkin_images, 6)}
              class="overflow-hidden rounded border border-border"
            >
              <img src={image.image_url} alt="Check-in image" class="h-40 w-full object-cover" />
              <figcaption class="px-3 py-2">
                <p class="text-sm font-medium text-text">
                  {Calendar.strftime(image.logged_at || Date.utc_today(), "%b %-d, %Y")}
                </p>
                <p class="mt-1 type-body-sm">{image.notes || "Check-in photo"}</p>
              </figcaption>
            </figure>
          </div>
        </section>

        <section>
          <header>
            <p class="type-label">Progress photos</p>
            <h2 class="mt-1 type-h2">Milestone gallery</h2>
          </header>

          <div class="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-3">
            <figure
              :for={image <- Enum.take(@progress_images, 6)}
              class="overflow-hidden rounded border border-border"
            >
              <img src={image.image_url} alt="Progress image" class="h-40 w-full object-cover" />
              <figcaption class="px-3 py-2">
                <p class="text-sm font-medium text-text">
                  {Calendar.strftime(image.logged_at || Date.utc_today(), "%b %-d, %Y")}
                </p>
                <p class="mt-1 type-body-sm">{image.notes || "Progress photo"}</p>
              </figcaption>
            </figure>
          </div>
        </section>
      </div>

      <aside class="gb-grid__side md:sticky md:top-6 md:self-start">
        <.stat_row>
          <:item label="Current">{format_weight(@latest_weight_kg)}</:item>
          <:item label="Check-ins">{length(@checkin_images)}</:item>
          <:item label="Progress">{length(@progress_images)}</:item>
        </.stat_row>
      </aside>
    </div>
    """
  end

  defp save_image(socket, upload_name, params, image_type, form_key, success_message) do
    current_user = socket.assigns.current_user

    uploaded_urls =
      consume_uploaded_entries(socket, upload_name, fn meta, entry ->
        {:ok, Uploads.store!("body-stats/#{current_user.id}", meta, entry)}
      end)

    case uploaded_urls do
      [] ->
        {:noreply, put_flash(socket, :error, "Choose an image before uploading.")}

      [image_url | _rest] ->
        attrs =
          params
          |> Map.put("image_type", image_type)
          |> Map.put("image_url", image_url)
          |> Map.put("user_id", current_user.id)

        case BodyStats.create_checkin_image(attrs) do
          {:ok, _image} ->
            {:noreply,
             socket
             |> assign_body_stats(current_user)
             |> assign_forms()
             |> put_flash(:info, success_message)}

          {:error, changeset} ->
            {:noreply, assign(socket, form_key, to_form(changeset))}
        end
    end
  end

  defp assign_body_stats(socket, current_user) do
    profile = Profiles.get_user_profile_by_user(current_user.id)
    weight_logs = BodyStats.list_body_weight_logs_for_user(current_user.id)

    weight_logs_chronological =
      BodyStats.list_body_weight_logs_for_user_chronological(current_user.id)

    latest_weight = BodyStats.latest_body_weight_log(current_user.id)

    socket
    |> assign(:profile, profile)
    |> assign(:weight_logs, weight_logs)
    |> assign(:weight_chart, build_weight_chart(weight_logs_chronological, profile))
    |> assign(
      :latest_weight_kg,
      (latest_weight && latest_weight.weight_kg) || (profile && profile.weight_kg)
    )
    |> assign(
      :checkin_images,
      BodyStats.list_checkin_images_for_user_by_type(current_user.id, "checkin")
    )
    |> assign(
      :progress_images,
      BodyStats.list_checkin_images_for_user_by_type(current_user.id, "progress")
    )
  end

  defp assign_forms(socket) do
    today = Date.utc_today()

    socket
    |> assign(
      :weight_form,
      to_form(BodyStats.change_body_weight_log(%BodyWeightLog{}, %{logged_at: today}))
    )
    |> assign(
      :progress_form,
      to_form(
        BodyStats.change_checkin_image(%CheckinImage{}, %{
          logged_at: today,
          image_type: "progress"
        }),
        as: :progress_photo
      )
    )
  end

  defp assign_image_form(socket, form_key, params, image_type, as) do
    form =
      %CheckinImage{}
      |> BodyStats.change_checkin_image(Map.put(params, "image_type", image_type))
      |> to_form(as: as)

    assign(socket, form_key, form)
  end

  defp build_weight_chart(weight_logs, profile) do
    points =
      case weight_logs do
        [] ->
          fallback_weight_point(profile)

        logs ->
          Enum.map(logs, fn log ->
            %{label: Calendar.strftime(log.logged_at, "%b %-d"), weight_kg: log.weight_kg}
          end)
      end

    weights = Enum.map(points, & &1.weight_kg)

    case weights do
      [] ->
        %{max_weight: nil, min_weight: nil, points: [], polyline_points: ""}

      _ ->
        min_weight = Enum.min(weights)
        max_weight = Enum.max(weights)
        lower_bound = min_weight - 5
        upper_bound = max_weight + 5
        x_step = chart_x_step(points)

        chart_points =
          points
          |> Enum.with_index()
          |> Enum.map(fn {%{label: label, weight_kg: weight_kg}, index} ->
            %{
              label: label,
              weight_kg: weight_kg,
              x: @chart_padding + x_step * index,
              y: scaled_weight_y(weight_kg, lower_bound, upper_bound)
            }
          end)

        %{
          max_weight: max_weight,
          min_weight: min_weight,
          points: chart_points,
          polyline_points: Enum.map_join(chart_points, " ", &"#{&1.x},#{&1.y}")
        }
    end
  end

  defp fallback_weight_point(nil), do: []

  defp fallback_weight_point(profile) do
    if profile && profile.weight_kg do
      [%{label: "Start", weight_kg: profile.weight_kg}]
    else
      []
    end
  end

  defp chart_x_step(points) when length(points) <= 1, do: 0.0

  defp chart_x_step(points) do
    (@chart_width - @chart_padding * 2) / (length(points) - 1)
  end

  defp scaled_weight_y(weight, lower_bound, upper_bound) do
    usable_height = @chart_height - @chart_padding * 2
    ratio = (weight - lower_bound) / max(upper_bound - lower_bound, 1)
    @chart_height - @chart_padding - ratio * usable_height
  end

  defp format_weight(nil), do: "--"
  defp format_weight(value) when is_integer(value), do: "#{value}.0 kg"

  defp format_weight(value) when is_float(value),
    do: "#{:erlang.float_to_binary(value, decimals: 1)} kg"

  defp upload_entry_name([entry | _rest]), do: entry.client_name
  defp upload_entry_name([]), do: nil
end
