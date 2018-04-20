defmodule OmiseGO.PerfTest.SenderServer do
  @moduledoc """
  The SenderServer process synchronously sends requested number of transactions to the blockchain server.
  """

  use GenServer

  @doc """
  Starts the server.
  """
  @spec start_link({senderid :: integer, nrequests :: integer, init_blocknum :: integer}) :: {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initializes the SenderServer process, register it into the Registry and schedules handle_info call.
  """
  @spec init({senderid :: integer, nrequests :: integer, init_blocknum :: integer}) :: {:ok, init_state :: tuple}
  def init({senderid, nrequests, init_blocknum}) do
    IO.puts "[#{senderid}] +++ init/1 called with requests: '#{nrequests}' +++"
    Registry.register(OmiseGO.PerfTest.Registry, :sender, "Sender: #{senderid}")

    sender_addr = generate_participant_address()
    IO.puts "[#{senderid}]: Address #{Base.encode64(sender_addr.addr)}"

    deposit_value = 10 * nrequests
    :ok = OmiseGO.API.State.deposit([%{owner: sender_addr.addr, amount: deposit_value, blknum: 1}])
    IO.puts "[#{senderid}]: Deposited #{deposit_value} OMG"

    send(self(), :do)
    {:ok, {senderid, sender_addr, nrequests, init_blocknum}}
  end

  @doc """
  Submits translaction then schedules call to itself if any requests left.
  Otherwise unregisters from the Registry and stops.
  """
  @spec handle_info(:do, state :: {senderid :: integer, sender_addr :: <<>>, nrequests :: integer, blocknum :: integer}) :: {:noreply, new_state :: tuple} | {:stop, :normal, nil}
  def handle_info(:do, state = {senderid, sender_addr, nrequests, blocknum}) do
    submit_tx(state)

    if nrequests > 0 do
      send(self(), :do)
      {:noreply, {senderid, sender_addr, nrequests-1, blocknum}}
    else
      Registry.unregister(OmiseGO.PerfTest.Registry, :sender)
      IO.puts "[#{senderid}] +++ Stoping... +++"
      {:stop, :normal, {senderid, sender_addr, nrequests, blocknum}}
    end
  end

  @doc """
  Updates state with current block number sent by CurrentBlockChecker process.
  """
  @spec handle_cast({:update, blocknum :: integer}, state :: tuple) :: {:noreply, new_state :: tuple}
  def handle_cast({:update, blocknum}, state) do
    {:noreply, put_elem(state, 3, blocknum)}
  end

  @doc """
  Submits new transaction to the blockchain server.
  """
  #FIXME: Add spec - SenderServer.submit_tx()
  def submit_tx({senderid, sender_addr, nrequests, blocknum}) do
    alias OmiseGO.API.State.Transaction

    # simulating time elapsed for tx send
    Process.sleep(500 + Enum.random([-250, 0, 250,]))

    receipient = generate_participant_address()
    IO.puts "[#{senderid}]: Sending Tx to new owner #{Base.encode64(receipient.addr)}"

    tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: receipient.addr, amount1: 7, newowner2: sender_addr.addr, amount2: 3, fee: 0,
      }
      |> Transaction.sign(sender_addr.priv, <<>>)
      |> Transaction.Signed.encode()

      {result, _} = OmiseGO.API.submit(tx)
      case result do
        {{:error,  reason}, _} -> IO.puts "[#{senderid}]: Transaction submition has failed, reason: #{reason}"
        {:ok, _} -> IO.puts "[#{senderid}]: Transaction submitted successfully"
      end
  end

  def generate_participant_address() do
    alias OmiseGO.API.Crypto
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end
end
