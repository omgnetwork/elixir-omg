defmodule OmiseGO.PerfTest.SenderServer do
  @moduledoc """
  The SenderServer process synchronously sends requested number of transactions to the blockchain server.
  """

  use GenServer

  @doc """
  Defines a structure for the State of the server.
  """
  defstruct [
    :senderid,
    :sender_addr,
    :nrequests,
    :blknum,      # initial state has to set to :senderid
    :txindex,
    :amount,
  ]
  @opaque state :: %__MODULE__{senderid: integer, sender_addr: <<>>, nrequests: integer, blknum: integer, txindex: integer, amount: integer}

  @doc """
  Starts the server.
  """
  @spec start_link({senderid :: integer, nrequests :: integer}) :: {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initializes the SenderServer process, register it into the Registry and schedules handle_info call.
  Assumptions:
    * Sender ids are sequencial positive int starting from 1, senders are initialized in order of sender id.
      This ensures all senders' deposits are accepted.
  """
  @spec init({senderid :: integer, nrequests :: integer}) :: {:ok, init_state :: __MODULE__.state}
  def init({senderid, nrequests}) do
    IO.puts "[#{senderid}] +++ init/1 called with requests: '#{nrequests}' +++"
    Registry.register(OmiseGO.PerfTest.Registry, :sender, "Sender: #{senderid}")

    sender_addr = generate_participant_address()
    IO.puts "[#{senderid}]: Address #{Base.encode64(sender_addr.addr)}"

    deposit_value = 10 * nrequests
    :ok = OmiseGO.API.State.deposit([%{owner: sender_addr.addr, amount: deposit_value, blknum: senderid}])
    IO.puts "[#{senderid}]: Deposited #{deposit_value} OMG"

    send(self(), :do)
    {:ok, {senderid, sender_addr, nrequests, senderid, 0, deposit_value}}
  end

  @doc """
  Submits translaction then schedules call to itself if any requests left.
  Otherwise unregisters from the Registry and stops.
  """
  @spec handle_info(:do, state :: __MODULE__.state) :: {:noreply, new_state :: __MODULE__.state} | {:stop, :normal, nil}
  def handle_info(:do, state = {senderid, sender_addr, nrequests, blknum, txindex, amount}) do
    if nrequests > 0 do
      {:ok, newtxindex, newvalue} = submit_tx(state)
      {:noreply, {senderid, sender_addr, nrequests-1, blknum, newtxindex, newvalue}}
    else
      Registry.unregister(OmiseGO.PerfTest.Registry, :sender)
      IO.puts "[#{senderid}] +++ Stoping... +++"
      {:stop, :normal, state}
    end
  end

  @doc """
  Updates state with current block number sent by CurrentBlockChecker process.
  """
  @spec handle_cast({:update, blknum :: integer}, state :: __MODULE__.state) :: {:noreply, new_state :: __MODULE__.state}
  def handle_cast({:update, blknum}, state) do
    send(self(), :do)

    #{:noreply, put_elem(state, 3, blknum)}
    {:noreply, put_elem(state, 3, 1000)}   # ignoring block from BlockChecker and sending always 1k
  end

  @doc """
  Submits new transaction to the blockchain server.
  """
  #FIXME: Add spec - SenderServer.submit_tx()
  def submit_tx({senderid, sender_addr, nrequests, blknum, txindex, amount}) do
    alias OmiseGO.API.State.Transaction

    to_spent = 9
    newamount = amount - to_spent
    receipient = generate_participant_address()
    IO.puts "[#{senderid}]: Sending Tx to new owner #{Base.encode64(receipient.addr)}"

    tx =
      %Transaction{
        blknum1: blknum, txindex1: txindex, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner2: receipient.addr, amount2: to_spent, newowner1: sender_addr.addr, amount1: newamount, fee: 0,
      }
      |> Transaction.sign(sender_addr.priv, <<>>)
      |> Transaction.Signed.encode()

      {result, txindex, _} = OmiseGO.API.submit(tx)
      case result do
        {:error,  reason} -> IO.puts "[#{senderid}]: Transaction submition has failed, reason: #{reason}"
        :ok -> IO.puts "[#{senderid}]: Transaction submitted successfully"
      end

      {result, txindex, newamount}
  end

  def generate_participant_address() do
    alias OmiseGO.API.Crypto
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end
end
