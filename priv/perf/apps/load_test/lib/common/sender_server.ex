# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule LoadTest.Common.SenderServer do
  @moduledoc """
  The SenderServer process synchronously sends requested number of transactions to the blockchain server.
  """

  # Waiting time (in milliseconds) before unsuccessful Tx submission is retried.
  @tx_retry_waiting_time_ms 333

  use GenServer

  alias LoadTest.ChildChain.Transaction
  alias LoadTest.Ethereum.Account

  require Logger

  @eth <<0::160>>

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
    :fee_amount,
    # {blknum, txindex, oindex, amount}, @see %LastTx above
    :last_tx,
    :child_chain_url,
    # tells whether recipients of the transactions should be random addresses (default) or self.
    :randomized
  ]

  @opaque state :: %__MODULE__{
            seqnum: integer,
            ntx_to_send: integer,
            spender: map,
            last_tx: LastTx.t(),
            randomized: boolean()
          }

  @doc """
  Starts the process.
  """
  @spec start_link({pos_integer(), map(), pos_integer(), keyword()}) :: {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initializes the SenderServer process, register it into the Registry and schedules handle_info call.
  Assumptions:
    * Senders are assigned sequential positive int starting from 1, senders are initialized in order of seqnum.
      This ensures all senders' deposits are accepted.

  Options:
    - :randomized - whether the non-change outputs of the txs sent out will be random or equal to sender (if `false`),
      defaults to `true`
  """
  @spec init({pos_integer(), map(), pos_integer(), keyword()}) :: {:ok, state()}
  def init({seqnum, utxo, ntx_to_send, fee_amount, opts}) do
    defaults = [randomized: true]
    opts = Keyword.merge(defaults, opts)

    _ =
      Logger.debug(
        "[#{inspect(seqnum)}] init called with utxo: #{inspect(utxo)} and requests: '#{inspect(ntx_to_send)}'"
      )

    send(self(), :do)
    {:ok, init_state(seqnum, utxo, ntx_to_send, fee_amount, opts)}
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
    _ = Logger.info("[#{inspect(seqnum)}] Stoping...")

    LoadTest.Common.SenderManager.sender_stats(%{seqnum: seqnum, blknum: blknum, txindex: txindex})
    {:stop, :normal, state}
  end

  def handle_info(:do, state) do
    newstate =
      state
      |> prepare_and_submit_tx()
      |> update_state_with_tx_submission(state)

    {:noreply, newstate}
  end

  defp prepare_and_submit_tx(state) do
    to_spend = 1
    new_amount = state.last_tx.amount - to_spend - state.fee_amount

    recipient =
      if state.randomized do
        {:ok, user} = Account.new()

        user
      else
        state.spender
      end

    _ =
      Logger.debug(
        "[#{inspect(state.seqnum)}]: Sending Tx to new owner #{Base.encode64(recipient.addr)}, left: #{
          inspect(new_amount)
        }"
      )

    recipient_output = [%ExPlasma.Utxo{owner: recipient.addr, currency: @eth, amount: to_spend}]
    # we aren't allowed to create zero-amount outputs, so if this is the last tx and no change is due, leave it out
    change_output =
      if new_amount > 0, do: [%ExPlasma.Utxo{owner: state.spender.addr, currency: @eth, amount: new_amount}], else: []

    [%{blknum: blknum, txindex: txindex, amount: amount} | _] =
      Transaction.submit_tx(
        [%ExPlasma.Utxo{blknum: state.last_tx.blknum, txindex: state.last_tx.txindex, oindex: state.last_tx.oindex}],
        change_output ++ recipient_output,
        [state.spender],
        1_000
      )

    _ =
      Logger.debug(
        "[#{inspect(state.seqnum)}]: Transaction submitted successfully {#{inspect(blknum)}, #{inspect(txindex)}}"
      )

    {:ok, blknum, txindex, amount}
  end

  # Handles result of successful Tx submission or retry request into new state and sends :do message
  @spec update_state_with_tx_submission(
          tx_submit_result :: {:ok, map} | :retry | {:error, any},
          state :: __MODULE__.state()
        ) :: __MODULE__.state()
  defp update_state_with_tx_submission(tx_submit_result, state) do
    case tx_submit_result do
      {:ok, newblknum, newtxindex, newvalue} ->
        send(self(), :do)

        if newblknum > state.last_tx.blknum,
          do:
            LoadTest.Common.SenderManager.sender_stats(%{
              seqnum: state.seqnum,
              blknum: state.last_tx.blknum,
              txindex: state.last_tx.txindex
            })

        next_state(state, newblknum, newtxindex, newvalue)

      :retry ->
        Process.send_after(self(), :do, @tx_retry_waiting_time_ms)
        state
    end
  end

  #   Generates module's initial state
  @spec init_state(pos_integer(), map(), pos_integer(), pos_integer(), keyword()) :: __MODULE__.state()
  defp init_state(seqnum, utxo, ntx_to_send, fee_amount, opts) do
    %{owner: spender, utxo_pos: utxo_pos, amount: amount} = utxo
    {:ok, %ExPlasma.Utxo{blknum: blknum, txindex: txindex, oindex: oindex}} = ExPlasma.Utxo.new(utxo_pos)

    %__MODULE__{
      seqnum: seqnum,
      ntx_to_send: ntx_to_send,
      spender: spender,
      fee_amount: fee_amount,
      last_tx: %LastTx{
        # initial state takes deposited value, put there on :init
        blknum: blknum,
        txindex: txindex,
        oindex: oindex,
        amount: amount
      },
      randomized: Keyword.get(opts, :randomized)
    }
  end

  # Generates next module's state
  @spec next_state(state :: __MODULE__.state(), blknum :: pos_integer, txindex :: pos_integer, amount :: pos_integer) ::
          __MODULE__.state()
  defp next_state(state, blknum, txindex, amount) do
    %__MODULE__{
      state
      | ntx_to_send: state.ntx_to_send - 1,
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
    _ = Logger.debug("[#{inspect(seqnum)}]: Need some sleep")
    [500, 800, 1000, 1300] |> Enum.random() |> Process.sleep()
  end
end
