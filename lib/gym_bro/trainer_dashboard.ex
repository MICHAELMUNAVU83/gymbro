defmodule GymBro.TrainerDashboard do
  @moduledoc """
  Read-model helpers for the trainer dashboard.
  """

  import Ecto.Query, warn: false

  alias GymBro.Analytics
  alias GymBro.BodyStats.{BodyWeightLog, CheckinImage}
  alias GymBro.Profiles.UserProfile
  alias GymBro.Repo
  alias GymBro.Trainer.TrainerClient
  alias GymBro.Training.WorkoutSession

  @checkin_alert_days 10

  def home(trainer_id, today \\ Date.utc_today()) do
    clients = list_clients(trainer_id)
    client_ids = Enum.map(clients, & &1.id)
    profiles = profiles_by_user_id(client_ids)
    active_sessions = active_sessions_by_user_id(client_ids)
    latest_sessions = latest_completed_sessions_by_user_id(client_ids)
    latest_checkins = latest_checkins_by_user_id(client_ids)

    client_cards =
      clients
      |> Enum.map(fn client ->
        build_client_card(
          client,
          Map.get(profiles, client.id),
          Map.get(active_sessions, client.id),
          Map.get(latest_sessions, client.id),
          Map.get(latest_checkins, client.id),
          today
        )
      end)

    %{
      summary: Analytics.trainer_summary(trainer_id),
      live_session_count: Enum.count(client_cards, & &1.live?),
      clients: client_cards,
      activity_feed: today_activity_feed(client_cards, today),
      alerts: attention_alerts(client_cards, today)
    }
  end

  defp list_clients(trainer_id) do
    Repo.all(
      from relationship in TrainerClient,
        join: client in assoc(relationship, :client),
        where: relationship.trainer_id == ^trainer_id,
        order_by: [asc: relationship.status, asc: client.email],
        select: %{
          id: client.id,
          email: client.email,
          joined_at: relationship.joined_at,
          notes: relationship.notes,
          status: relationship.status
        }
    )
  end

  defp profiles_by_user_id([]), do: %{}

  defp profiles_by_user_id(user_ids) do
    Repo.all(
      from profile in UserProfile,
        where: profile.user_id in ^user_ids,
        select: {profile.user_id, profile}
    )
    |> Map.new()
  end

  defp active_sessions_by_user_id([]), do: %{}

  defp active_sessions_by_user_id(user_ids) do
    Repo.all(
      from session in WorkoutSession,
        left_join: workout_day in assoc(session, :workout_day),
        where: session.user_id in ^user_ids and session.status == "active",
        order_by: [desc: session.started_at, desc: session.inserted_at],
        select:
          {session.user_id,
           %{
             id: session.id,
             started_at: session.started_at,
             workout_day_id: session.workout_day_id,
             workout_name: workout_day.day_label
           }}
    )
    |> first_row_per_key()
  end

  defp latest_completed_sessions_by_user_id([]), do: %{}

  defp latest_completed_sessions_by_user_id(user_ids) do
    Repo.all(
      from session in WorkoutSession,
        left_join: workout_day in assoc(session, :workout_day),
        where: session.user_id in ^user_ids and session.status == "completed",
        order_by: [desc: session.completed_at, desc: session.inserted_at],
        select:
          {session.user_id,
           %{
             completed_at: session.completed_at,
             workout_name: workout_day.day_label
           }}
    )
    |> first_row_per_key()
  end

  defp latest_checkins_by_user_id([]), do: %{}

  defp latest_checkins_by_user_id(user_ids) do
    Repo.all(
      from image in CheckinImage,
        where: image.user_id in ^user_ids and image.visible_to_trainer == true,
        order_by: [desc: image.logged_at, desc: image.inserted_at],
        select: {image.user_id, %{logged_at: image.logged_at, image_type: image.image_type}}
    )
    |> first_row_per_key()
  end

  defp today_activity_feed(client_cards, today) do
    client_lookup = Map.new(client_cards, &{&1.id, &1})
    client_ids = Map.keys(client_lookup)
    {start_of_day, end_of_day} = day_bounds(today)

    session_items =
      completed_session_feed_items(client_ids, client_lookup, start_of_day, end_of_day) ++
        active_session_feed_items(client_ids, client_lookup, start_of_day, end_of_day)

    body_weight_items = body_weight_feed_items(client_ids, client_lookup, today)
    checkin_items = checkin_feed_items(client_ids, client_lookup, today)

    (session_items ++ body_weight_items ++ checkin_items)
    |> Enum.sort_by(& &1.sort_at, {:desc, DateTime})
    |> Enum.take(8)
  end

  defp completed_session_feed_items([], _client_lookup, _start_of_day, _end_of_day), do: []

  defp completed_session_feed_items(client_ids, client_lookup, start_of_day, end_of_day) do
    Repo.all(
      from session in WorkoutSession,
        left_join: workout_day in assoc(session, :workout_day),
        where:
          session.user_id in ^client_ids and session.status == "completed" and
            not is_nil(session.completed_at) and session.completed_at >= ^start_of_day and
            session.completed_at <= ^end_of_day,
        order_by: [desc: session.completed_at],
        select: %{
          client_id: session.user_id,
          duration_seconds: session.duration_seconds,
          occurred_at: session.completed_at,
          workout_name: workout_day.day_label
        }
    )
    |> Enum.map(fn item ->
      client = Map.fetch!(client_lookup, item.client_id)

      %{
        badge: "Workout",
        client_id: client.id,
        client_name: client.display_name,
        detail:
          [item.workout_name || "Workout", duration_label(item.duration_seconds)]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" - "),
        icon_class: "bg-emerald-400/20 text-emerald-200",
        sort_at: item.occurred_at,
        title: "#{client.display_name} completed a session"
      }
    end)
  end

  defp active_session_feed_items([], _client_lookup, _start_of_day, _end_of_day), do: []

  defp active_session_feed_items(client_ids, client_lookup, start_of_day, end_of_day) do
    Repo.all(
      from session in WorkoutSession,
        left_join: workout_day in assoc(session, :workout_day),
        where:
          session.user_id in ^client_ids and session.status == "active" and
            not is_nil(session.started_at) and session.started_at >= ^start_of_day and
            session.started_at <= ^end_of_day,
        order_by: [desc: session.started_at],
        select: %{
          client_id: session.user_id,
          occurred_at: session.started_at,
          workout_name: workout_day.day_label
        }
    )
    |> Enum.map(fn item ->
      client = Map.fetch!(client_lookup, item.client_id)

      %{
        badge: "Live",
        client_id: client.id,
        client_name: client.display_name,
        detail: "#{item.workout_name || "Workout"} in progress",
        icon_class: "bg-green-400/20 text-green-200",
        sort_at: item.occurred_at,
        title: "#{client.display_name} started a live session"
      }
    end)
  end

  defp body_weight_feed_items([], _client_lookup, _today), do: []

  defp body_weight_feed_items(client_ids, client_lookup, today) do
    Repo.all(
      from log in BodyWeightLog,
        where: log.user_id in ^client_ids and log.logged_at == ^today,
        order_by: [desc: log.inserted_at],
        select: %{
          client_id: log.user_id,
          occurred_at: log.inserted_at,
          weight_kg: log.weight_kg
        }
    )
    |> Enum.map(fn item ->
      client = Map.fetch!(client_lookup, item.client_id)

      %{
        badge: "Weight",
        client_id: client.id,
        client_name: client.display_name,
        detail: "#{format_weight(item.weight_kg)} kg logged",
        icon_class: "bg-blue-400/20 text-blue-200",
        sort_at: item.occurred_at,
        title: "#{client.display_name} checked in on bodyweight"
      }
    end)
  end

  defp checkin_feed_items([], _client_lookup, _today), do: []

  defp checkin_feed_items(client_ids, client_lookup, today) do
    Repo.all(
      from image in CheckinImage,
        where:
          image.user_id in ^client_ids and image.logged_at == ^today and
            image.visible_to_trainer == true,
        order_by: [desc: image.inserted_at],
        select: %{
          client_id: image.user_id,
          image_type: image.image_type,
          occurred_at: image.inserted_at
        }
    )
    |> Enum.map(fn item ->
      client = Map.fetch!(client_lookup, item.client_id)

      %{
        badge: "Check-in",
        client_id: client.id,
        client_name: client.display_name,
        detail: "#{pretty_image_type(item.image_type)} photo uploaded",
        icon_class: "bg-orange-400/20 text-orange-200",
        sort_at: item.occurred_at,
        title: "#{client.display_name} shared a progress photo"
      }
    end)
  end

  defp attention_alerts(client_cards, today) do
    client_cards
    |> Enum.filter(&(&1.status == "active"))
    |> Enum.flat_map(&client_alerts(&1, today))
    |> Enum.sort_by(&{alert_rank(&1.level), -&1.days_open, &1.client_name})
    |> Enum.take(6)
  end

  defp client_alerts(client, today) do
    [stale_session_alert(client, today), stale_checkin_alert(client, today)]
    |> Enum.reject(&is_nil/1)
  end

  defp stale_session_alert(%{live?: true}, _today), do: nil

  defp stale_session_alert(client, today) do
    threshold_days = stale_session_threshold(client.days_per_week)

    case client.last_completed_on do
      nil ->
        %{
          client_id: client.id,
          client_name: client.display_name,
          days_open: threshold_days + 1,
          detail: "No completed sessions logged yet.",
          level: :high,
          title: "Missed sessions"
        }

      last_date ->
        days_since = Date.diff(today, last_date)

        if days_since >= threshold_days do
          %{
            client_id: client.id,
            client_name: client.display_name,
            days_open: days_since,
            detail: "Last workout was #{days_since} days ago.",
            level: if(days_since >= threshold_days + 2, do: :high, else: :medium),
            title: "Missed sessions"
          }
        end
    end
  end

  defp stale_checkin_alert(client, today) do
    case client.last_checkin_on do
      nil ->
        %{
          client_id: client.id,
          client_name: client.display_name,
          days_open: @checkin_alert_days + 1,
          detail: "No check-in photos shared yet.",
          level: :medium,
          title: "No check-in"
        }

      last_date ->
        days_since = Date.diff(today, last_date)

        if days_since >= @checkin_alert_days do
          %{
            client_id: client.id,
            client_name: client.display_name,
            days_open: days_since,
            detail: "Last check-in was #{days_since} days ago.",
            level: :medium,
            title: "No check-in"
          }
        end
    end
  end

  defp build_client_card(client, profile, active_session, latest_session, latest_checkin, today) do
    last_completed_on =
      latest_session && latest_session.completed_at &&
        DateTime.to_date(latest_session.completed_at)

    %{
      days_per_week: profile && profile.days_per_week,
      display_name: display_name(client.email),
      email: client.email,
      goal_label: pretty_goal(profile && profile.goal),
      id: client.id,
      initials: initials(client.email),
      joined_at: client.joined_at,
      last_checkin_on: latest_checkin && latest_checkin.logged_at,
      last_completed_on: last_completed_on,
      last_session_label: session_label(active_session, latest_session, today),
      live?: not is_nil(active_session),
      live_session: active_session,
      status: client.status,
      training_frequency_label: frequency_label(profile && profile.days_per_week)
    }
  end

  defp first_row_per_key(rows) do
    Enum.reduce(rows, %{}, fn {key, value}, acc -> Map.put_new(acc, key, value) end)
  end

  defp stale_session_threshold(nil), do: 6
  defp stale_session_threshold(1), do: 8
  defp stale_session_threshold(2), do: 6
  defp stale_session_threshold(3), do: 5
  defp stale_session_threshold(4), do: 4
  defp stale_session_threshold(days_per_week) when days_per_week >= 5, do: 3
  defp stale_session_threshold(_days_per_week), do: 6

  defp session_label(
         %{started_at: started_at, workout_name: workout_name},
         _latest_session,
         _today
       ) do
    "Live now - #{workout_name || "Workout"} since #{time_label(started_at)}"
  end

  defp session_label(nil, %{completed_at: completed_at, workout_name: workout_name}, today) do
    day_text = relative_day_text(DateTime.to_date(completed_at), today)
    "#{workout_name || "Workout"} completed #{day_text}"
  end

  defp session_label(nil, nil, _today), do: "No workouts logged yet"

  defp day_bounds(today) do
    {
      DateTime.new!(today, ~T[00:00:00], "Etc/UTC"),
      DateTime.new!(today, ~T[23:59:59], "Etc/UTC")
    }
  end

  defp duration_label(nil), do: nil

  defp duration_label(duration_seconds) when duration_seconds < 60 do
    "#{duration_seconds}s"
  end

  defp duration_label(duration_seconds) do
    minutes = div(duration_seconds, 60)
    "#{minutes} min"
  end

  defp format_weight(weight) when is_float(weight),
    do: :erlang.float_to_binary(weight, decimals: 1)

  defp format_weight(weight), do: to_string(weight)

  defp pretty_goal("maintenance"), do: "Maintenance"
  defp pretty_goal("muscle_gain"), do: "Muscle gain"
  defp pretty_goal("weight_loss"), do: "Weight loss"
  defp pretty_goal(nil), do: "Plan pending"
  defp pretty_goal(goal), do: goal

  defp pretty_image_type(nil), do: "Progress"

  defp pretty_image_type(image_type) do
    image_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp frequency_label(nil), do: "Program pending"
  defp frequency_label(days_per_week), do: "#{days_per_week} days/week"

  defp relative_day_text(date, today) do
    case Date.diff(today, date) do
      0 -> "today"
      1 -> "yesterday"
      days -> "#{days} days ago"
    end
  end

  defp time_label(nil), do: "now"
  defp time_label(datetime), do: Calendar.strftime(datetime, "%H:%M")

  defp alert_rank(:high), do: 0
  defp alert_rank(:medium), do: 1
  defp alert_rank(:low), do: 2
  defp alert_rank(_level), do: 3

  defp display_name(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.replace(~r/[^a-zA-Z0-9]+/, " ")
    |> String.trim()
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp initials(email) do
    email
    |> display_name()
    |> String.split()
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> case do
      "" -> "GB"
      value -> value
    end
  end
end
