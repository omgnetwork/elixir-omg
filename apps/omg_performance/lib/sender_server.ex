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

defmodule OMG.Performance.SenderServer do
  @moduledoc """
  The SenderServer process synchronously sends requested number of transactions to the blockchain server.
  """

  # Waiting time (in milliseconds) before unsuccessful Tx submission is retried.
  @tx_retry_waiting_time_ms 333

  use GenServer
  use OMG.API.LoggerExt

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.TestHelper
  alias OMG.API.Utxo

  require Utxo

  @eth Crypto.zero_address()

  defmodule LastTx do
    @moduledoc """
    Keeps last transaction sent by sender, remembered for next submission.
    """
    defstruct [:blknum, :txindex, :oindex, :amount]
    @type t :: %__MODULE__{blknum: integer, txindex: integer, oindex: integer, amount: integer}
  end

  @doc """
  Defines a structure for the State of the server.
  """
  defstruct [
    # increasing number to ensure sender's deposit is accepted, @seealso @doc to :init
    :seqnum,
    :ntx_to_send,
    :spender,
    # {blknum, txindex, oindex, amount}, @see %LastTx above
    :last_tx
  ]

  @opaque state :: %__MODULE__{
            seqnum: integer,
            ntx_to_send: integer,
            spender: map,
            last_tx: LastTx.t()
          }

  @doc """
  Starts the process.
  """
  @spec start_link({pos_integer(), map(), pos_integer()}) :: {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initializes the SenderServer process, register it into the Registry and schedules handle_info call.
  Assumptions:
    * Senders are assigned sequential positive int starting from 1, senders are initialized in order of seqnum.
      This ensures all senders' deposits are accepted.
  """
  @spec init({pos_integer(), map(), pos_integer()}) :: {:ok, state()}
  def init({seqnum, utxo, ntx_to_send}) do
    _ =
      Logger.debug(fn ->
        "[#{inspect(seqnum)}] init called with utxo: #{inspect(utxo)} and requests: '#{inspect(ntx_to_send)}'"
      end)

    send(self(), :do)

    {:ok, init_state(seqnum, utxo, ntx_to_send)}
  end

  @doc """
  Submits transaction then schedules call to itself if more left.
  Otherwise unregisters from the Registry and stops.
  """
  @spec handle_info(:do, state :: __MODULE__.state()) ::
          {:noreply, new_state :: __MODULE__.state()} | {:stop, :normal, __MODULE__.state()}
  def handle_info(
        :do,
        %__MODULE__{ntx_to_send: 0, seqnum: seqnum, last_tx: %LastTx{blknum: blknum, txindex: txindex}} = state
      ) do
    _ = Logger.info(fn -> "[#{inspect(seqnum)}] Stoping..." end)

    OMG.Performance.SenderManager.sender_stats(%{seqnum: seqnum, blknum: blknum, txindex: txindex})
    {:stop, :normal, state}
  end

  def handle_info(:do, %__MODULE__{} = state) do
    newstate =
      state
      |> prepare_new_tx()
      |> submit_tx(state)
      |> update_state_with_tx_submission(state)

    {:noreply, newstate}
  end

  defp prepare_new_tx(%__MODULE__{seqnum: seqnum, spender: spender, last_tx: last_tx}) do
    to_spend = 1
    newamount = last_tx.amount - to_spend
    recipient = TestHelper.generate_entity()

    _ =
      Logger.debug(fn ->
        "[#{inspect(seqnum)}]: Sending Tx to new owner #{Base.encode64(recipient.addr)}, left: #{inspect(newamount)}"
      end)

    # create and return signed transaction
    [{last_tx.blknum, last_tx.txindex, last_tx.oindex}]
    |> Transaction.new([{spender.addr, @eth, newamount}, {recipient.addr, @eth, to_spend}])
    |> Transaction.sign([spender.priv, <<>>])
  end

  # Submits new transaction to the blockchain server.
  @spec submit_tx(Transaction.Signed.t(), __MODULE__.state()) ::
          {:ok, blknum :: pos_integer, txindex :: pos_integer, newamount :: pos_integer}
          | {:error, any()}
          | :retry
  defp submit_tx(tx, %__MODULE__{seqnum: seqnum}) do
    result =
      tx
      |> Transaction.Signed.encode()
      |> submit_tx_jsonrpc()

    case result do
      {:error, {-32_603, "Internal error", "too_many_transactions_in_block"}} ->
        _ =
          Logger.info(fn ->
            "[#{inspect(seqnum)}]: Transaction submission will be retried, block is full."
          end)

        :retry

      {:error, reason} ->
        _ =
          Logger.info(fn ->
            "[#{inspect(seqnum)}]: Transaction submission has failed, reason: #{inspect(reason)}"
          end)

        {:error, reason}

      {:ok, %{blknum: blknum, tx_index: txindex}} ->
        _ =
          Logger.debug(fn ->
            "[#{inspect(seqnum)}]: Transaction submitted successfully {#{inspect(blknum)}, #{inspect(txindex)}}"
          end)

        [%{amount: amount} | _] = Transaction.get_outputs(tx.raw_tx)
        {:ok, blknum, txindex, amount}
    end
  end

  # Handles result of successful Tx submission or retry request into new state and sends :do message
  @spec update_state_with_tx_submission(
          tx_submit_result :: {:ok, map} | :retry | {:error, any},
          state :: __MODULE__.state()
        ) :: __MODULE__.state()
  defp update_state_with_tx_submission(
         tx_submit_result,
         %__MODULE__{seqnum: seqnum, last_tx: last_tx} = state
       ) do
    case tx_submit_result do
      {:ok, newblknum, newtxindex, newvalue} ->
        send(self(), :do)

        if newblknum > last_tx.blknum,
          do:
            OMG.Performance.SenderManager.sender_stats(%{
              seqnum: seqnum,
              blknum: last_tx.blknum,
              txindex: last_tx.txindex
            })

        state |> next_state(newblknum, newtxindex, newvalue)

      :retry ->
        Process.send_after(self(), :do, @tx_retry_waiting_time_ms)
        state
    end
  end

  # Submits Tx to the child chain server via http (JsonRPC) and translates successful result to atom-keyed map.
  @spec submit_tx_jsonrpc(binary) :: {:ok, map} | {:error, any}
  defp submit_tx_jsonrpc(encoded_tx) do
    OMG.JSONRPC.Client.call(:submit, %{transaction: encoded_tx})
  end

  #   Generates module's initial state
  @spec init_state(pos_integer(), map(), pos_integer()) :: __MODULE__.state()
  defp init_state(seqnum, %{owner: spender, utxo_pos: utxo_pos, amount: amount}, ntx_to_send) do
    {:utxo_position, blknum, txindex, oindex} = Utxo.Position.decode(utxo_pos)

    %__MODULE__{
      seqnum: seqnum,
      ntx_to_send: ntx_to_send,
      spender: spender,
      last_tx: %LastTx{
        # initial state takes deposited value, put there on :init
        blknum: blknum,
        txindex: txindex,
        oindex: oindex,
        amount: amount
      }
    }
  end

  # Generates next module's state
  @spec next_state(state :: __MODULE__.state(), blknum :: pos_integer, txindex :: pos_integer, amount :: pos_integer) ::
          __MODULE__.state()
  defp next_state(%__MODULE__{ntx_to_send: ntx_to_send} = state, blknum, txindex, amount) do
    %__MODULE__{
      state
      | ntx_to_send: ntx_to_send - 1,
        last_tx: %LastTx{
          state.last_tx
          | blknum: blknum,
            txindex: txindex,
            amount: amount
        }
    }
  end

  @doc """
  Helper function to test interaction between Performance modules by adding random delay
  NOTE: Made public to avoid compilation error when function isn't used.
  """
  @spec random_sleep(integer) :: :ok
  def random_sleep(seqnum) do
    _ = Logger.debug(fn -> "[#{inspect(seqnum)}]: Need some sleep" end)
    [500, 800, 1000, 1300] |> Enum.random() |> Process.sleep()
  end
end
