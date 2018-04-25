defmodule OmiseGO.PerfTest.SenderServer do
  @moduledoc """
  The SenderServer process synchronously sends requested number of transactions to the blockchain server.
  """

  require Logger
  use GenServer

  defmodule LastTx do
    defstruct [:blknum, :txindex, :oindex, :amount]
    @type t :: %__MODULE__{blknum: integer, txindex: integer, oindex: integer, amount: integer}
  end

  @doc """
  Defines a structure for the State of the server.
  """
  defstruct [
    :seqnum,
    :nrequests,
    :spender,
    :last_tx,     #{blknum, txindex, oindex, amount}
  ]
  @opaque state :: %__MODULE__{seqnum: integer, nrequests: integer, spender: map, last_tx: LastTx.t}

  @doc """
  Starts the server.
  """
  @spec start_link({seqnum :: integer, nrequests :: integer}) :: {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initializes the SenderServer process, register it into the Registry and schedules handle_info call.
  Assumptions:
    * Sender ids are sequencial positive int starting from 1, senders are initialized in order of sender id.
      This ensures all senders' deposits are accepted.
  """
  @spec init({seqnum :: integer, nrequests :: integer}) :: {:ok, init_state :: __MODULE__.state}
  def init({seqnum, nrequests}) do
    Logger.debug "[#{seqnum}] +++ init/1 called with requests: '#{nrequests}' +++"
    Registry.register(OmiseGO.PerfTest.Registry, :sender, "Sender: #{seqnum}")

    spender = generate_participant_address()
    Logger.debug "[#{seqnum}]: Address #{Base.encode64(spender.addr)}"

    deposit_value = 10 * nrequests
    :ok = OmiseGO.API.State.deposit([%{owner: spender.addr, amount: deposit_value, blknum: seqnum}])
    Logger.debug "[#{seqnum}]: Deposited #{deposit_value} OMG"

    send(self(), :do)
    {:ok, init_state(seqnum, nrequests, spender)}
  end

  @doc """
  Submits translaction then schedules call to itself if any requests left.
  Otherwise unregisters from the Registry and stops.
  """
  @spec handle_info(:do, state :: __MODULE__.state) :: {:noreply, new_state :: __MODULE__.state} | {:stop, :normal, nil}
  def handle_info(:do, state = %__MODULE__{seqnum: seqnum, nrequests: nrequests}) do
    if nrequests > 0 do
      {:ok, newblknum, newtxindex, newvalue} = submit_tx(state)
      send(self(), :do)
      {:noreply, %__MODULE__{state | nrequests: nrequests-1} |> with_tx(newblknum, newtxindex, newvalue)}
    else
      Registry.unregister(OmiseGO.PerfTest.Registry, :sender)
      Logger.debug "[#{seqnum}] +++ Stoping... +++"
      {:stop, :normal, state}
    end
  end

  @doc """
  Submits new transaction to the blockchain server.
  """
  #FIXME: Add spec - SenderServer.submit_tx()
  def submit_tx(%__MODULE__{seqnum: seqnum, spender: spender, last_tx: last_tx}) do
    alias OmiseGO.API.State.Transaction

    to_spent = 9
    newamount = last_tx.amount - to_spent
    receipient = generate_participant_address()
    Logger.debug "[#{seqnum}]: Sending Tx to new owner #{Base.encode64(receipient.addr)}, left: #{newamount}"

    tx =
      %Transaction{
        blknum1: last_tx.blknum, txindex1: last_tx.txindex, oindex1: last_tx.oindex, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner2: receipient.addr, amount2: to_spent, newowner1: spender.addr, amount1: newamount, fee: 0,
      }
      |> Transaction.sign(spender.priv, <<>>)
      |> Transaction.Signed.encode()

      {result, blknum, txindex, _} = OmiseGO.API.submit(tx)
      case result do
        {:error,  reason} -> Logger.debug "[#{seqnum}]: Transaction submition has failed, reason: #{reason}"
        :ok -> Logger.debug "[#{seqnum}]: Transaction submitted successfully"
      end

      {result, blknum, txindex, newamount}
  end

  def generate_participant_address() do
    alias OmiseGO.API.Crypto
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end

  defp init_state(seqnum, nreq, spender) do
    %__MODULE__{seqnum: seqnum, nrequests: nreq, spender: spender,
      last_tx: %LastTx{blknum: seqnum, txindex: 0, oindex: 0, amount: 10*nreq}
    }
  end

  defp with_tx(state, blknum, txindex, amount) do
    %__MODULE__{state | last_tx: %LastTx{state.last_tx | blknum: blknum, txindex: txindex, amount: amount}}
  end
end
