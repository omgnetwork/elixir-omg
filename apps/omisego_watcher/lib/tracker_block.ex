defmodule OmiseGOWatcher.TrackerOmisego do
  use GenServer
  alias OmiseGOWatcher.{UtxoDB, Validator}
  alias OmiseGO.API.Block
  alias OmiseGO.Eth

  def jsonrpc(method, params) do
    jsonrpc_port = Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)
    OmiseGO.JSONRPC.Helper.jsonrpc("http://localhost:#{jsonrpc_port}", method, params, OmiseGO.API)
  end

  defp ask_for_block(from, to, contract) when from <= to do
    with {:ok, {hash, _time}} <- Eth.get_child_chain(from, contract),
         {:ok, recive} <- jsonrpc(:get_block, %{hash: Base.encode16(hash)}),
         {:ok, %Block{} = block} <- Validator.json_to_block(recive, from) do
      UtxoDB.consume_block(block, from)
      ask_for_block(from + Application.get_env(:omisego_eth, :child_block_interval), to, contract)
    else
      err ->
        {:error, from - 1_000}
    end
  end

  defp ask_for_block(_, to, _), do: {:ok, to}

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_opts) do
    env = Application.get_env(:omisego_watcher, OmiseGOWatcher.TrackerOmisego)
    {:ok, _} = :timer.send_interval(2_000, self(), :check_for_new_block)

    {:ok,
     %{
       child_block_number: UtxoDB.top_block_number(),
       contract_address: env[:contract_address],
     }}
  end

  def handle_info(:check_for_new_block, state) do
    {:ok, child_block} = OmiseGO.Eth.get_current_child_block(state.contract_address)
    child_block_interval = Application.get_env(:omisego_eth, :child_block_interval)
    child_block = child_block - child_block_interval

    cond do
      child_block > state.child_block_number ->
        {:ok, child_block_number} =
          ask_for_block(state.child_block_number + child_block_interval, child_block, state.contract_address)

        {:noreply, %{state | child_block_number: child_block_number}}

      true ->
        {:noreply, state}
    end
  end
end
