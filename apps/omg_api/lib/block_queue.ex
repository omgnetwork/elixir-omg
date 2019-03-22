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

defmodule OMG.API.BlockQueue do
  @moduledoc """
  Responsible for keeping a queue of blocks lined up for submission to Ethereum.
  Responsible for determining the cadence of forming/submitting blocks to Ethereum.
  Responsible for determining correct gas price and ensuring submissions get mined eventually.

  In particular responsible for picking up, where it's left off (crashed) gracefully.

  Relies on RootChain contract having reorg protection ('decimals for deposits' part).
  Relies on RootChain contract's 'authority' account not being used to send any other transaction.

  Reacts to external requests of changing gas price and resubmits block submission transactions not being mined.
  For changing the gas price it needs external signals (e.g. from a price oracle)
  """

  alias OMG.API.BlockQueue.Core
  alias OMG.API.BlockQueue.Core.BlockSubmission
  alias OMG.API.FreshBlocks
  alias OMG.Block
  alias OMG.Recorder

  @type eth_height() :: non_neg_integer()
  @type hash() :: BlockSubmission.hash()
  @type plasma_block_num() :: BlockSubmission.plasma_block_num()
  # child chain block number, as assigned by plasma contract
  @type encoded_signed_tx() :: binary()

  @doc """
  Enqueues child chain block to be submitted to Ethereum
  """
  @spec enqueue_block(Block.t()) :: :ok
  def enqueue_block(block) do
    GenServer.cast(__MODULE__.Server, {:enqueue_block, block})
  end

  defmodule Server do
    @moduledoc """
    Handles timing of calls to root chain.
    Driven by block height and mined transaction data delivered by local geth node and new blocks
    formed by server. Resubmits transaction until it is mined.
    """

    use GenServer
    use OMG.LoggerExt
    alias OMG.Eth

    def start_link(_args) do
      GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def init(:ok) do
      {:ok, %{}, {:continue, :setup}}
    end

    def handle_continue(:setup, %{}) do
      _ = Logger.info("Starting #{__MODULE__} service.")
      :ok = Eth.node_ready()
      :ok = Eth.RootChain.contract_ready()
      {:ok, parent_height} = Eth.get_ethereum_height()
      {:ok, mined_num} = Eth.RootChain.get_mined_child_block()
      {:ok, parent_start} = Eth.RootChain.get_root_deployment_height()
      {:ok, child_block_interval} = Eth.RootChain.get_child_block_interval()
      {:ok, stored_child_top_num} = OMG.DB.get_single_value(:child_top_block_number)
      {:ok, finality_threshold} = Application.fetch_env(:omg_api, :submission_finality_margin)

      _ =
        Logger.info(
          "Starting BlockQueue at " <>
            "parent_height: #{inspect(parent_height)}, parent_start: #{inspect(parent_start)}, " <>
            "mined_child_block: #{inspect(mined_num)}, stored_child_top_block: #{inspect(stored_child_top_num)}"
        )

      range =
        Core.child_block_nums_to_init_with(mined_num, stored_child_top_num, child_block_interval, finality_threshold)

      {:ok, known_hashes} = OMG.DB.block_hashes(range)
      {:ok, {top_mined_hash, _}} = Eth.RootChain.get_child_chain(mined_num)
      _ = Logger.info("Starting BlockQueue, top_mined_hash: #{inspect(Base.encode16(top_mined_hash))}")

      {:ok, state} =
        with {:ok, _state} = result <-
               Core.new(
                 mined_child_block_num: mined_num,
                 known_hashes: Enum.zip(range, known_hashes),
                 top_mined_hash: top_mined_hash,
                 parent_height: parent_height,
                 child_block_interval: child_block_interval,
                 chain_start_parent_height: parent_start,
                 minimal_enqueue_block_gap: Application.fetch_env!(:omg_api, :child_block_minimal_enqueue_gap),
                 finality_threshold: finality_threshold,
                 last_enqueued_block_at_height: parent_height
               ) do
          result
        else
          {:error, reason} = error when reason in [:mined_hash_not_found_in_db, :contract_ahead_of_db] ->
            _ =
              Logger.error(
                "The child chain might have not been wiped clean when starting a child chain from scratch. Check README.MD and follow the setting up child chain."
              )

            error

          other ->
            other
        end

      interval = Application.fetch_env!(:omg_api, :block_queue_eth_height_check_interval_ms)
      {:ok, _} = :timer.send_interval(interval, self(), :check_ethereum_status)

      {:ok, _} = Recorder.start_link(%Recorder{name: __MODULE__.Recorder, parent: self()})

      _ = Logger.info("Started BlockQueue")
      {:noreply, state}
    end

    @doc """
    Checks the status of the Ethereum root chain, the top mined child block number
    and status of State to decide what to do
    """
    def handle_info(:check_ethereum_status, %Core{} = state) do
      {:ok, height} = Eth.get_ethereum_height()
      {:ok, mined_blknum} = Eth.RootChain.get_mined_child_block()
      {_, is_empty_block} = OMG.State.get_status()

      _ = Logger.debug("Ethereum at \#'#{inspect(height)}', mined child at \#'#{inspect(mined_blknum)}'")

      state1 =
        with {:do_form_block, state1} <- Core.set_ethereum_status(state, height, mined_blknum, is_empty_block) do
          :ok = OMG.State.form_block()
          state1
        else
          {:dont_form_block, state1} -> state1
        end

      submit_blocks(state1)
      {:noreply, state1}
    end

    def handle_cast({:enqueue_block, %Block{number: block_number, hash: block_hash} = block}, %Core{} = state) do
      {:ok, parent_height} = Eth.get_ethereum_height()
      state1 = Core.enqueue_block(state, block_hash, block_number, parent_height)
      _ = Logger.info("Enqueuing block num '#{inspect(block_number)}', hash '#{inspect(Base.encode16(block_hash))}'")

      FreshBlocks.push(block)
      submit_blocks(state1)
      {:noreply, state1}
    end

    # private (server)

    @spec submit_blocks(Core.t()) :: :ok
    defp submit_blocks(%Core{} = state) do
      state
      |> Core.get_blocks_to_submit()
      |> Enum.each(&submit/1)
    end

    defp submit(%Core.BlockSubmission{hash: hash, nonce: nonce, gas_price: gas_price} = submission) do
      _ = Logger.debug("Submitting: #{inspect(submission)}")

      submit_result = OMG.Eth.RootChain.submit_block(hash, nonce, gas_price)
      {:ok, newest_mined_blknum} = Eth.RootChain.get_mined_child_block()

      :ok = Core.process_submit_result(submission, submit_result, newest_mined_blknum)
    end
  end
end
