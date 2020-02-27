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

defmodule OMG.Performance.SenderServer do
  @moduledoc """
  The SenderServer process synchronously sends requested number of transactions to the blockchain server.
  """

  # Waiting time (in milliseconds) before unsuccessful Tx submission is retried.
  @tx_retry_waiting_time_ms 333
  @fees_amount 1

  use GenServer
  use OMG.Utils.LoggerExt

  alias OMG.DevCrypto
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias OMG.Utxo
  alias OMG.Watcher.HttpRPC.Client
  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

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
            child_chain_url: binary(),
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
  def init({seqnum, utxo, ntx_to_send, opts}) do
    defaults = [randomized: true]
    opts = Keyword.merge(defaults, opts)

    _ =
      Logger.debug(
        "[#{inspect(seqnum)}] init called with utxo: #{inspect(utxo)} and requests: '#{inspect(ntx_to_send)}'"
      )

    send(self(), :do)
    {:ok, init_state(seqnum, utxo, ntx_to_send, opts)}
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

  defp prepare_new_tx(%__MODULE__{seqnum: seqnum, spender: spender, last_tx: last_tx, randomized: randomized}) do
    to_spend = 1
    new_amount = last_tx.amount - to_spend - @fees_amount
    recipient = if randomized, do: TestHelper.generate_entity(), else: spender

    _ =
      Logger.debug(
        "[#{inspect(seqnum)}]: Sending Tx to new owner #{Base.encode64(recipient.addr)}, left: #{inspect(new_amount)}"
      )

    recipient_output = [{recipient.addr, @eth, to_spend}]
    # we aren't allowed to create zero-amount outputs, so if this is the last tx and no change is due, leave it out
    change_output = if new_amount > 0, do: [{spender.addr, @eth, new_amount}], else: []

    # create and return signed transaction
    [{last_tx.blknum, last_tx.txindex, last_tx.oindex}]
    |> Transaction.Payment.new(change_output ++ recipient_output)
    |> DevCrypto.sign([spender.priv])
  end

  # Submits new transaction to the blockchain server.
  @spec submit_tx(Transaction.Signed.t(), __MODULE__.state()) ::
          {:ok, blknum :: pos_integer, txindex :: pos_integer, new_amount :: pos_integer}
          | {:error, any()}
          | :retry
  defp submit_tx(tx, %__MODULE__{seqnum: seqnum, child_chain_url: child_chain_url}) do
    result =
      tx
      |> Transaction.Signed.encode()
      |> submit_tx_rpc(child_chain_url)

    case result do
      {:error, {:client_error, %{"code" => "submit:too_many_transactions_in_block"}}} ->
        _ = Logger.info("[#{inspect(seqnum)}]: Transaction submission will be retried, block is full.")
        :retry

      {:error, reason} ->
        _ = Logger.info("[#{inspect(seqnum)}]: Transaction submission has failed, reason: #{inspect(reason)}")
        {:error, reason}

      {:ok, %{"blknum" => blknum, "txindex" => txindex}} ->
        _ =
          Logger.debug(
            "[#{inspect(seqnum)}]: Transaction submitted successfully {#{inspect(blknum)}, #{inspect(txindex)}}"
          )

        [%{amount: amount} | _] = Transaction.get_outputs(tx)
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

  # Submits Tx to the child chain server via http (Http-RPC) and translates successful result to atom-keyed map.
  @spec submit_tx_rpc(binary, binary()) :: {:ok, map} | {:error, any}
  defp submit_tx_rpc(encoded_tx, child_chain_url) do
    Client.submit(encoded_tx, child_chain_url)
  end

  #   Generates module's initial state
  @spec init_state(pos_integer(), map(), pos_integer(), keyword()) :: __MODULE__.state()
  defp init_state(seqnum, %{owner: spender, utxo_pos: utxo_pos, amount: amount}, ntx_to_send, opts) do
    Utxo.position(blknum, txindex, oindex) = Utxo.Position.decode!(utxo_pos)

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
      },
      child_chain_url: Application.fetch_env!(:omg_watcher, :child_chain_url),
      randomized: Keyword.get(opts, :randomized)
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
    _ = Logger.debug("[#{inspect(seqnum)}]: Need some sleep")
    [500, 800, 1000, 1300] |> Enum.random() |> Process.sleep()
  end
end
