defmodule OmiseGO.Performance.SenderServer do
  @moduledoc """
  The SenderServer process synchronously sends requested number of transactions to the blockchain server.
  """

  require Logger
  use GenServer

  defmodule LastTx do
    @moduledoc """
    Submodule defines structure to keep last transaction sent by sender remembered fo the next submission.
    """
    defstruct [:blknum, :txindex, :oindex, :amount]
    @type t :: %__MODULE__{blknum: integer, txindex: integer, oindex: integer, amount: integer}
  end

  @doc """
  Defines a structure for the State of the server.
  """
  defstruct [
    :seqnum,      # increasing number to ensure sender's deposit is accepted, @seealso @doc to :init
    :ntx_to_send,
    :spender,
    :last_tx,     # {blknum, txindex, oindex, amount}, @see %LastTx above
  ]
  @opaque state :: %__MODULE__{seqnum: integer, ntx_to_send: integer, spender: map, last_tx: LastTx.t}

  @doc """
  Starts the server.
  """
  @spec start_link({seqnum :: integer, ntx_to_send :: integer}) :: {:ok, pid}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initializes the SenderServer process, register it into the Registry and schedules handle_info call.
  Assumptions:
    * Senders are assigned sequential positive int starting from 1, senders are initialized in order of seqnum.
      This ensures all senders' deposits are accepted.
  """
  @spec init({seqnum :: integer, ntx_to_send :: integer}) :: {:ok, init_state :: __MODULE__.state}
  def init({seqnum, ntx_to_send}) do
    Logger.debug(fn -> "[#{seqnum}] +++ init/1 called with requests: '#{ntx_to_send}' +++" end)
    Registry.register(OmiseGO.Performance.Registry, :sender, "Sender: #{seqnum}")

    spender = generate_participant_address()
    Logger.debug(fn -> "[#{seqnum}]: Address #{Base.encode64(spender.addr)}" end)

    deposit_value = 10 * ntx_to_send
    owner_enc = "0x" <> Base.encode16(spender.addr, case: :lower)
    :ok = OmiseGO.API.State.deposit([%{owner: owner_enc, amount: deposit_value, blknum: seqnum}])

    Logger.debug(fn -> "[#{seqnum}]: Deposited #{deposit_value} OMG" end)

    send(self(), :do)
    {:ok, init_state(seqnum, ntx_to_send, spender)}
  end

  @doc """
  Submits transaction then schedules call to itself if more left.
  Otherwise unregisters from the Registry and stops.
  """
  @spec handle_info(:do, state :: __MODULE__.state) :: {:noreply, new_state :: __MODULE__.state} | {:stop, :normal, nil}
  def handle_info(:do, %__MODULE__{seqnum: seqnum, ntx_to_send: ntx_to_send} = state) do
    if ntx_to_send > 0 do
      {:ok, newblknum, newtxindex, newvalue} = submit_tx(state)
      send(self(), :do)
      {:noreply, state |> next_state(newblknum, newtxindex, newvalue)}
    else
      Registry.unregister(OmiseGO.Performance.Registry, :sender)
      Logger.debug(fn -> "[#{seqnum}] +++ Stoping... +++" end)
      {:stop, :normal, state}
    end
  end

  @doc """
  Submits new transaction to the blockchain server.
  """
  @spec submit_tx(__MODULE__.state)
  :: {result :: tuple, blknum :: pos_integer, txindex :: pos_integer, newamount :: pos_integer}
  def submit_tx(%__MODULE__{seqnum: seqnum, spender: spender, last_tx: last_tx}) do
    alias OmiseGO.API.State.Transaction

    to_spend = 9
    newamount = last_tx.amount - to_spend
    recipient = generate_participant_address()
    Logger.debug(fn -> "[#{seqnum}]: Sending Tx to new owner #{Base.encode64(recipient.addr)}, left: #{newamount}" end)

    tx =
      [{last_tx.blknum, last_tx.txindex, last_tx.oindex}]
      |> Transaction.new([{spender.addr, newamount}, {recipient.addr, to_spend}], 0)
      |> Transaction.sign(spender.priv, <<>>)
      |> Transaction.Signed.encode()

      result = OmiseGO.API.submit(Base.encode16(tx))
      case result do
        {:error,  reason} ->
          Logger.debug(fn -> "[#{seqnum}]: Transaction submission has failed, reason: #{reason}" end)
          {:error, reason}

        {:ok,%{ blknum: blknum, tx_index:  txindex}} ->
          Logger.debug(fn -> "[#{seqnum}]: Transaction submitted successfully" end)
          {:ok, blknum, txindex, newamount}
      end
  end

  @doc """
  Generates participant private key and address
  """
  @spec generate_participant_address() :: %{priv: <<_::256>>, addr: <<_::160>>}
  def generate_participant_address do
    alias OmiseGO.API.Crypto
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, addr} = Crypto.generate_address(pub)
    %{priv: priv, addr: addr}
  end

  # Generates module's initial state
  @spec init_state(
    seqnum :: pos_integer,
    nreq :: pos_integer,
    spender :: %{priv: <<_::256>>,
    addr: <<_::160>>})
  :: __MODULE__.state
  defp init_state(seqnum, nreq, spender) do
    %__MODULE__{
      seqnum: seqnum,
      ntx_to_send: nreq,
      spender: spender,
      last_tx: %LastTx{
        blknum: seqnum,   # initial state takes deposited value, put there on :init
        txindex: 0,
        oindex: 0,
        amount: 10 * nreq,
      },
    }
  end

  # Generates next module's state
  @spec next_state(
    state :: __MODULE__.state,
    blknum :: pos_integer,
    txindex :: pos_integer,
    amount :: pos_integer)
  :: __MODULE__.state
  defp next_state(%__MODULE__{ntx_to_send: ntx_to_send} = state, blknum, txindex, amount) do
    %__MODULE__{
      state |
      ntx_to_send: ntx_to_send - 1,
      last_tx: %LastTx{
        state.last_tx |
        blknum: blknum, txindex: txindex, amount: amount
      }
    }
  end
end
