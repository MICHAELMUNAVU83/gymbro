defmodule GymBro.Training.WorkoutClock do
  @moduledoc false

  use GenServer

  alias GymBro.Training

  def child_spec(opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    %{
      id: {__MODULE__, session_id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient
    }
  end

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(session_id))
  end

  def ensure_started(session_id, started_at) do
    case lookup(session_id) do
      {:ok, pid} ->
        GenServer.cast(pid, {:sync_started_at, started_at})
        :ok

      :error ->
        case DynamicSupervisor.start_child(
               GymBro.WorkoutClockSupervisor,
               {__MODULE__, session_id: session_id, started_at: started_at}
             ) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, pid}} ->
            GenServer.cast(pid, {:sync_started_at, started_at})
            :ok

          {:error, {:shutdown, {:failed_to_start_child, _child, {:already_started, pid}}}} ->
            GenServer.cast(pid, {:sync_started_at, started_at})
            :ok

          other ->
            other
        end
    end
  end

  def stop(session_id) do
    case lookup(session_id) do
      {:ok, pid} -> DynamicSupervisor.terminate_child(GymBro.WorkoutClockSupervisor, pid)
      :error -> :ok
    end
  end

  @impl true
  def init(opts) do
    state = %{
      session_id: Keyword.fetch!(opts, :session_id),
      started_at: normalize_started_at(Keyword.get(opts, :started_at))
    }

    broadcast_tick(state)
    schedule_tick()

    {:ok, state}
  end

  @impl true
  def handle_cast({:sync_started_at, started_at}, state) do
    next_state = %{state | started_at: normalize_started_at(started_at)}
    broadcast_tick(next_state)
    {:noreply, next_state}
  end

  @impl true
  def handle_info(:tick, state) do
    broadcast_tick(state)
    schedule_tick()
    {:noreply, state}
  end

  defp broadcast_tick(state) do
    Training.broadcast_workout_event(state.session_id, :elapsed_tick, %{
      elapsed_seconds: elapsed_seconds(state.started_at),
      started_at: state.started_at
    })
  end

  defp elapsed_seconds(started_at) do
    max(DateTime.diff(DateTime.utc_now(), started_at, :second), 1)
  end

  defp normalize_started_at(%DateTime{} = started_at), do: DateTime.truncate(started_at, :second)
  defp normalize_started_at(_started_at), do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp schedule_tick, do: Process.send_after(self(), :tick, 1_000)

  defp lookup(session_id) do
    case Registry.lookup(GymBro.WorkoutClockRegistry, session_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> :error
    end
  end

  defp via_tuple(session_id), do: {:via, Registry, {GymBro.WorkoutClockRegistry, session_id}}
end
