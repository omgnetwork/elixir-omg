defmodule Front.Aggregator do
  use GenServer

  require Logger

  alias Front.Repo.TestRun

  @dump_interval 5_000

  def start_link(key) do
    GenServer.start_link(__MODULE__, key)
  end

  def record_metrics(pid, params) do
    GenServer.cast(pid, {:record_metrics, params})
  end

  def state(pid) do
    GenServer.call(pid, :state)
  end

  def dump(pid) do
    GenServer.cast(pid, :dump)
  end

  def finish(pid) do
    GenServer.cast(pid, :finish)
  end

  @impl true
  def init(key) do
    test_run = key |> to_string() |> TestRun.create!()

    {:ok, _timer} = :timer.send_interval(@dump_interval, :dump)

    {:ok, {test_run, %{transactions_count: 0, errors_count: 0, errors: %{}}}}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:record_metrics, data}, {test_run, state}) do
    transactions_count = state.transactions_count + 1

    {errors_count, errors} = maybe_add_new_error(state, data)

    new_state = %{
      state
      | errors_count: errors_count,
        errors: errors,
        transactions_count: transactions_count
    }

    {:noreply, {test_run, new_state}}
  end

  @impl true
  def handle_cast(:dump, {test_run, state}) do
    updated_test_run = TestRun.update!(test_run, %{data: state})

    {:noreply, {updated_test_run, state}}
  end

  @impl true
  def handle_cast(:finish, {test_run, state}) do
    updated_test_run = TestRun.update!(test_run, %{state: "finished"})

    {:noreply, {updated_test_run, state}}
  end

  @impl true
  def handle_info(:dump, {test_run, state}) do
    updated_test_run = TestRun.update!(test_run, %{data: state})

    {:noreply, {updated_test_run, state}}
  end

  defp maybe_add_new_error(state, %{status: :ok}) do
    {state.errors_count, state.errors}
  end

  defp maybe_add_new_error(state, data) do
    new_errors_count = state.errors_count + 1

    errors = Map.update(state.errors, data[:type], 1, fn existing_value -> existing_value + 1 end)

    {new_errors_count, errors}
  end
end
