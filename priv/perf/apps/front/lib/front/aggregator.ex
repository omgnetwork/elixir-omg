defmodule Front.Aggregator do
  use GenServer

  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def record_metrics(pid, params) do
    GenServer.cast(pid, {:record_metrics, params})
  end

  def state(pid) do
    GenServer.call(pid, :state)
  end

  @impl true
  def init(_) do
    {:ok, %{transactions_count: 0, errors_count: 0, errors: %{}}}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:record_metrics, data}, state) do
    transactions_count = state.transactions_count + 1

    {errors_count, errors} = maybe_add_new_error(state, data)

    new_state = %{
      state
      | errors_count: errors_count,
        errors: errors,
        transactions_count: transactions_count
    }

    {:noreply, new_state}
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
