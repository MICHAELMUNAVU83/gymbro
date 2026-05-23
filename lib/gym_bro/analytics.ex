defmodule GymBro.Analytics do
  @moduledoc """
  Read-focused aggregate queries for dashboards and reporting.
  """

  import Ecto.Query, warn: false

  alias GymBro.Accounts.User
  alias GymBro.BodyStats.{BodyWeightLog, CheckinImage, PersonalRecord}
  alias GymBro.Profiles.UserProfile
  alias GymBro.Repo
  alias GymBro.Trainer.ClientInvitation
  alias GymBro.Trainer.TrainerClient
  alias GymBro.Training.WorkoutSession

  def athlete_summary(user_id) do
    latest_weight =
      Repo.one(
        from log in BodyWeightLog,
          where: log.user_id == ^user_id,
          order_by: [desc: log.logged_at, desc: log.inserted_at],
          select: log.weight_kg,
          limit: 1
      )

    %{
      total_sessions: count(WorkoutSession, user_id: user_id),
      completed_sessions: count(WorkoutSession, user_id: user_id, status: "completed"),
      personal_records: count(PersonalRecord, user_id: user_id),
      checkins: count(CheckinImage, user_id: user_id),
      latest_weight_kg: latest_weight
    }
  end

  def trainer_summary(trainer_id) do
    client_ids =
      Repo.all(
        from relationship in TrainerClient,
          where: relationship.trainer_id == ^trainer_id,
          select: relationship.client_id
      )

    %{
      total_clients: count(TrainerClient, trainer_id: trainer_id),
      active_clients: count(TrainerClient, trainer_id: trainer_id, status: "active"),
      pending_invitations: count(ClientInvitation, trainer_id: trainer_id, status: "pending"),
      total_client_sessions: count_for_ids(WorkoutSession, :user_id, client_ids),
      completed_client_sessions: count_for_ids(WorkoutSession, :user_id, client_ids, "completed")
    }
  end

  def trainer_overview(trainer_id, today \\ Date.utc_today()) do
    summary = trainer_summary(trainer_id)
    clients = trainer_clients(trainer_id)
    client_ids = Enum.map(clients, & &1.id)
    week_dates = week_dates(today)
    week_start = hd(week_dates)
    week_end = List.last(week_dates)

    completed_this_week =
      completed_session_counts_between(client_ids, week_start, week_end)

    earliest_weights = earliest_weight_by_user_id(client_ids)
    latest_weights = latest_weight_by_user_id(client_ids)

    client_metrics =
      Enum.map(clients, fn client ->
        planned_days = client.days_per_week || 0
        completed_sessions = Map.get(completed_this_week, client.id, 0)
        consistency_percent = consistency_percent(planned_days, completed_sessions)
        start_weight = Map.get(earliest_weights, client.id) || client.start_weight_kg
        current_weight = Map.get(latest_weights, client.id) || start_weight
        weight_lost_kg = weight_lost(start_weight, current_weight)

        %{
          client_id: client.id,
          client_name: display_name(client.email),
          completed_this_week: completed_sessions,
          consistency_percent: consistency_percent,
          current_weight_kg: current_weight,
          planned_days: planned_days,
          start_weight_kg: start_weight,
          weight_lost_kg: weight_lost_kg
        }
      end)

    weight_loss_leaders =
      client_metrics
      |> Enum.filter(&((&1.weight_lost_kg || 0.0) > 0.0))
      |> Enum.sort_by(
        fn client -> {client.weight_lost_kg, client.consistency_percent, client.client_name} end,
        :desc
      )
      |> Enum.take(5)

    %{
      summary: summary,
      avg_consistency: average_consistency_snapshot(client_metrics),
      aggregate: aggregate_weight_stats(client_metrics, completed_this_week),
      weight_loss_leaders: weight_loss_leaders,
      week_range_label: week_range_label(week_start, week_end)
    }
  end

  defp count(schema, filters) do
    schema
    |> where(^filters)
    |> Repo.aggregate(:count)
  end

  defp trainer_clients(trainer_id) do
    Repo.all(
      from relationship in TrainerClient,
        join: client in User,
        on: client.id == relationship.client_id,
        left_join: profile in UserProfile,
        on: profile.user_id == client.id,
        where: relationship.trainer_id == ^trainer_id and relationship.status == "active",
        order_by: [asc: client.email],
        select: %{
          days_per_week: profile.days_per_week,
          email: client.email,
          id: client.id,
          start_weight_kg: profile.weight_kg
        }
    )
  end

  defp completed_session_counts_between([], _start_date, _end_date), do: %{}

  defp completed_session_counts_between(client_ids, start_date, end_date) do
    start_of_day = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(end_date, ~T[23:59:59], "Etc/UTC")

    Repo.all(
      from session in WorkoutSession,
        where:
          session.user_id in ^client_ids and session.status == "completed" and
            not is_nil(session.completed_at) and session.completed_at >= ^start_of_day and
            session.completed_at <= ^end_of_day,
        group_by: session.user_id,
        select: {session.user_id, count(session.id)}
    )
    |> Map.new()
  end

  defp earliest_weight_by_user_id([]), do: %{}

  defp earliest_weight_by_user_id(client_ids) do
    Repo.all(
      from log in BodyWeightLog,
        where: log.user_id in ^client_ids,
        order_by: [asc: log.logged_at, asc: log.inserted_at],
        select: {log.user_id, log.weight_kg}
    )
    |> first_row_per_key()
  end

  defp latest_weight_by_user_id([]), do: %{}

  defp latest_weight_by_user_id(client_ids) do
    Repo.all(
      from log in BodyWeightLog,
        where: log.user_id in ^client_ids,
        order_by: [desc: log.logged_at, desc: log.inserted_at],
        select: {log.user_id, log.weight_kg}
    )
    |> first_row_per_key()
  end

  defp average_consistency_snapshot(client_metrics) do
    consistent_clients =
      Enum.filter(client_metrics, fn client -> client.planned_days > 0 end)

    percent =
      case consistent_clients do
        [] -> 0
        clients -> round(Enum.sum(Enum.map(clients, & &1.consistency_percent)) / length(clients))
      end

    %{
      client_count: length(consistent_clients),
      percent: percent
    }
  end

  defp aggregate_weight_stats(client_metrics, completed_this_week) do
    clients_with_weight_data =
      Enum.filter(client_metrics, fn client ->
        is_number(client.start_weight_kg) and is_number(client.current_weight_kg)
      end)

    clients_losing_weight =
      Enum.filter(clients_with_weight_data, fn client -> (client.weight_lost_kg || 0.0) > 0.0 end)

    average_weight_lost_kg =
      case clients_losing_weight do
        [] -> 0.0
        clients -> Enum.sum(Enum.map(clients, & &1.weight_lost_kg)) / length(clients)
      end

    %{
      average_weight_lost_kg: round_weight(average_weight_lost_kg),
      clients_losing_weight_count: length(clients_losing_weight),
      clients_with_weight_data_count: length(clients_with_weight_data),
      total_weight_lost_kg:
        clients_losing_weight
        |> Enum.map(& &1.weight_lost_kg)
        |> Enum.sum()
        |> round_weight(),
      weekly_completed_sessions: Enum.sum(Map.values(completed_this_week))
    }
  end

  defp count_for_ids(_schema, _field, []), do: 0
  defp count_for_ids(schema, field, ids), do: count_for_ids(schema, field, ids, nil)

  defp count_for_ids(_schema, _field, [], _status), do: 0

  defp count_for_ids(schema, field, ids, status) do
    query =
      from record in schema,
        where: field(record, ^field) in ^ids

    query =
      if status do
        from record in query, where: record.status == ^status
      else
        query
      end

    Repo.aggregate(query, :count)
  end

  defp consistency_percent(0, _completed_sessions), do: 0

  defp consistency_percent(planned_days, completed_sessions) do
    min(round(completed_sessions / planned_days * 100), 100)
  end

  defp weight_lost(start_weight, current_weight)
       when is_number(start_weight) and is_number(current_weight) do
    round_weight(max(start_weight - current_weight, 0.0))
  end

  defp weight_lost(_start_weight, _current_weight), do: nil

  defp round_weight(value) when is_integer(value), do: value * 1.0
  defp round_weight(value) when is_float(value), do: Float.round(value, 1)
  defp round_weight(_value), do: nil

  defp week_dates(today) do
    beginning_of_week = Date.add(today, 1 - Date.day_of_week(today))
    Enum.map(0..6, &Date.add(beginning_of_week, &1))
  end

  defp week_range_label(week_start, week_end) do
    "#{Calendar.strftime(week_start, "%b %-d")} - #{Calendar.strftime(week_end, "%b %-d")}"
  end

  defp first_row_per_key(rows) do
    Enum.reduce(rows, %{}, fn {key, value}, acc -> Map.put_new(acc, key, value) end)
  end

  defp display_name(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.replace(~r/[^a-zA-Z0-9]+/, " ")
    |> String.trim()
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
