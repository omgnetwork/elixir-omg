# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.BlockGetter do
  @moduledoc """
  Checking if there are new block from child chain on ethereum.
  Checking if Block from child chain is valid
  Download new block from child chain and update State, TransactionDB, UtxoDB.
  Manage simultaneous getting and stateless-processing of blocks and manage the results of that
  Detects byzantine situations like BlockWithholding and InvalidBlock and passes this events to Eventer
  """
  alias OMG.API.Block
  alias OMG.Eth
  alias OMG.Watcher.BlockGetter.Core
  alias OMG.Watcher.Eventer
  alias OMG.Watcher.UtxoDB

  use GenServer
  use OMG.API.LoggerExt

  @spec get_block(pos_integer()) ::
          {:ok, Block.t() | Core.PotentialWithholding.t()} | {:error, Core.block_error(), binary(), pos_integer()}
  def get_block(requested_number) do
    {:ok, {requested_hash, _time}} = Eth.get_child_chain(requested_number)
    rpc_response = OMG.JSONRPC.Client.call(:get_block, %{hash: requested_hash})
    Core.validate_get_block_response(rpc_response, requested_hash, requested_number, :os.system_time(:millisecond))
  end

  def handle_cast(
        {:consume_block, %{transactions: transactions, number: blknum, zero_fee_requirements: fees} = block},
        state
      ) do
    state_exec_results = for tx <- transactions, do: OMG.API.State.exec(tx, fees)

    {continue, events} = Core.check_tx_executions(state_exec_results, block)

    Eventer.emit_events(events)

    with :ok <- continue do
      response = OMG.Watcher.TransactionDB.update_with(block)
      nil = Enum.find(response, &(!match?({:ok, _}, &1)))
      _ = UtxoDB.update_with(block)
      _ = Logger.info(fn -> "Consumed block \##{inspect(blknum)}" end)
      {:ok, next_child} = Eth.get_current_child_block()
      {new_state, blocks_numbers} = Core.get_new_blocks_numbers(state, next_child)
      :ok = run_block_get_task(blocks_numbers)

      _ =
        Logger.info(fn ->
          "Child chain seen at block \##{inspect(next_child)}. Getting blocks #{inspect(blocks_numbers)}"
        end)

      child_block_interval = Application.get_env(:omg_eth, :child_block_interval)

      # FIXME: substitute for Ethereum height where this block originated from (see bugs in tracker)
      #       after we have a way to cheaply get it using RootChainCoordinator
      eth_height = 0
      :ok = OMG.API.State.close_block(child_block_interval, eth_height)

      {:noreply, new_state}
    else
      {:needs_stopping, reason} ->
        _ = Logger.error(fn -> "Stopping BlockGetter becasue of #{inspect(reason)}" end)
        {:stop, :shutdown, state}
    end
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, block_number} = OMG.DB.child_top_block_number()
    child_block_interval = Application.get_env(:omg_eth, :child_block_interval)
    {:ok, _} = :timer.send_after(0, self(), :producer)

    maximum_block_withholding_time_ms = Application.get_env(:omg_watcher, :maximum_block_withholding_time_ms)

    {
      :ok,
      Core.init(
        block_number,
        child_block_interval,
        maximum_block_withholding_time_ms: maximum_block_withholding_time_ms
      )
    }
  end

  @spec handle_info(
          :producer
          | {reference(), {:got_block, {:ok, map}}}
          | {reference(), {:got_block, {:error, Core.block_error()}}}
          | {:DOWN, reference(), :process, pid, :normal},
          Core.t()
        ) :: {:noreply, Core.t()} | {:stop, :normal, Core.t()}
  def handle_info(msg, state)

  def handle_info(:producer, state) do
    {:ok, next_child} = Eth.get_current_child_block()

    {new_state, blocks_numbers} = Core.get_new_blocks_numbers(state, next_child)

    _ =
      Logger.info(fn ->
        "Child chain seen at block \##{inspect(next_child)}. Getting blocks #{inspect(blocks_numbers)}"
      end)

    :ok = run_block_get_task(blocks_numbers)

    {:ok, _} = :timer.send_after(2_000, self(), :producer)
    {:noreply, new_state}
  end

  def handle_info({_ref, {:got_block, response}}, state) do
    # 1/ process the block that arrived and consume
    {continue, new_state, blocks_to_consume, events} = Core.handle_got_block(state, response)

    Eventer.emit_events(events)

    with :ok <- continue do
      Enum.each(blocks_to_consume, fn block -> GenServer.cast(__MODULE__, {:consume_block, block}) end)
      {:noreply, new_state}
    else
      {:needs_stopping, reason} ->
        _ = Logger.error(fn -> "Stopping BlockGetter becasue of #{inspect(reason)}" end)
        {:stop, :shutdown, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal} = _process, state), do: {:noreply, state}

  defp run_block_get_task(blocks_numbers) do
    blocks_numbers
    |> Enum.each(
      # captures the result in handle_info/2 with the atom: got_block
      &Task.async(fn -> {:got_block, get_block(&1)} end)
    )
  end
end
