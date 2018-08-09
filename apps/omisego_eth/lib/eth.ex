defmodule OmiseGO.Eth do
  @moduledoc """
  Adapter/port to ethereum.

  All sending of transactions and listening to events goes here
  """
  # TODO: decide how type and logic aware this should be. Presently it's quite mixed

  alias OmiseGO.API.Crypto
  import OmiseGO.Eth.Encoding

  @type contract_t() :: binary | nil

  @spec node_ready() :: :ok | {:error, :geth_still_syncing | :geth_not_listening}
  def node_ready do
    case Ethereumex.HttpClient.eth_syncing() do
      {:ok, false} -> :ok
      {:ok, true} -> {:error, :geth_still_syncing}
      {:error, :econnrefused} -> {:error, :geth_not_listening}
    end
  end

  @doc """
  Check geth syncing status, errors are treated as not synced.
  Returns:
   * false - geth is synced
   * true  - geth is still syncing.
  """
  @spec syncing?() :: boolean
  def syncing?, do: node_ready() != :ok

  @spec contract_ready(contract_t()) ::
          :ok | {:error, :root_chain_contract_not_available | :root_chain_authority_is_nil}
  def contract_ready(contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)

    try do
      {:ok, addr} = authority(contract)

      case addr != <<0::256>> do
        true -> :ok
        false -> {:error, :root_chain_authority_is_nil}
      end
    rescue
      _ -> {:error, :root_chain_contract_not_available}
    end
  end

  defmodule BlockSubmission do
    @moduledoc false

    @type hash() :: <<_::256>>
    @type plasma_block_num() :: non_neg_integer()

    @type t() :: %__MODULE__{
            num: plasma_block_num(),
            hash: hash(),
            nonce: non_neg_integer(),
            gas_price: pos_integer()
          }
    defstruct [:num, :hash, :nonce, :gas_price]
  end

  @spec get_root_deployment_height(binary() | nil, contract_t()) :: {:ok, integer()} | Ethereumex.HttpClient.error()
  def get_root_deployment_height(txhash \\ nil, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)
    txhash = txhash || Application.get_env(:omisego_eth, :txhash_contract)

    case Ethereumex.HttpClient.eth_get_transaction_receipt(txhash) do
      {:ok, %{"contractAddress" => ^contract, "blockNumber" => "0x" <> height_hex}} ->
        {height, ""} = Integer.parse(height_hex, 16)
        {:ok, height}

      {:ok, _} ->
        {:error, :wrong_contract_address}

      other ->
        other
    end
  end

  @spec submit_block(BlockSubmission.t(), Crypto.address_t() | nil, contract_t()) ::
          {:error, binary() | atom() | map()}
          | {:ok, binary()}
  def submit_block(
        %BlockSubmission{hash: hash, nonce: nonce, gas_price: gas_price},
        from \\ nil,
        contract \\ nil
      ) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)
    from = from || Application.get_env(:omisego_eth, :authority_addr)

    data =
      "submitBlock(bytes32)"
      |> ABI.encode([hash])
      |> Base.encode16()

    gas = 100_000

    Ethereumex.HttpClient.eth_send_transaction(%{
      from: from,
      to: contract,
      gas: encode_eth_rpc_unsigned_int(gas),
      gasPrice: encode_eth_rpc_unsigned_int(gas_price),
      data: "0x#{data}",
      nonce: encode_eth_rpc_unsigned_int(nonce)
    })
  end

  def start_deposit_exit(deposit_positon, value, gas_price, from, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)

    data =
      "startDepositExit(uint256,uint256)"
      |> ABI.encode([deposit_positon, value])
      |> Base.encode16()

    gas = 1_000_000

    Ethereumex.HttpClient.eth_send_transaction(%{
      from: from,
      to: contract,
      data: "0x#{data}",
      gas: encode_eth_rpc_unsigned_int(gas),
      gasPrice: encode_eth_rpc_unsigned_int(gas_price)
    })
  end

  def start_exit(utxo_position, txbytes, proof, sigs, gas_price, from, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)

    data =
      "startExit(uint256,bytes,bytes,bytes)"
      |> ABI.encode([utxo_position, txbytes, proof, sigs])
      |> Base.encode16()

    gas = 1_000_000

    Ethereumex.HttpClient.eth_send_transaction(%{
      from: from,
      to: contract,
      data: "0x#{data}",
      gas: encode_eth_rpc_unsigned_int(gas),
      gasPrice: encode_eth_rpc_unsigned_int(gas_price)
    })
  end

  def get_ethereum_height do
    case Ethereumex.HttpClient.eth_block_number() do
      {:ok, "0x" <> height_hex} ->
        {height, ""} = Integer.parse(height_hex, 16)
        {:ok, height}

      other ->
        other
    end
  end

  @doc """
  Returns next blknum that is supposed to be mined by operator
  """
  def get_current_child_block(contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)
    call_contract_value(contract, "currentChildBlock()")
  end

  @doc """
  Returns blknum that was already mined by operator (with exception for 0)
  """
  def get_mined_child_block(contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)

    with {:ok, next} <- call_contract_value(contract, "currentChildBlock()"),
         do: {:ok, next - 1000}
  end

  def authority(contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)
    {:ok, {operator_address}} = call_contract(contract, "operator()", [], [:address])
    {:ok, operator_address}
  end

  @doc """
  Returns lists of deposits sorted by child chain block number
  """
  def get_deposits(block_from, block_to, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)

    event = encode_event_signature("Deposit(address,uint256,address,uint256)")

    parse_deposit = fn %{"data" => "0x" <> deposit} ->
      [owner, blknum, token, amount] =
        deposit
        |> Base.decode16!(case: :lower)
        |> ABI.TypeDecoder.decode_raw([:address, {:uint, 256}, :address, {:uint, 256}])

      {:ok, owner} = Crypto.encode_address(owner)
      {:ok, token} = Crypto.encode_address(token)
      %{owner: owner, currency: token, amount: amount, blknum: blknum}
    end

    with {:ok, unfiltered_logs} <- get_ethereum_logs(block_from, block_to, event, contract),
         deposits <- unfiltered_logs |> filter_not_removed |> Enum.map(parse_deposit),
         do: {:ok, Enum.sort(deposits, &(&1.blknum > &2.blknum))}
  end

  @doc """
  Returns lists of block submissions sorted by timestamp
  """
  def get_block_submissions(block_from, block_to, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)

    event = encode_event_signature("BlockSubmitted(bytes32,uint256)")

    parse_block_submissions = fn %{"data" => "0x" <> block_submission, "blockNumber" => "0x" <> hex_block_number} ->
      {eth_height, ""} = Integer.parse(hex_block_number, 16)

      [root, timestamp] =
        block_submission
        |> Base.decode16!(case: :lower)
        |> ABI.TypeDecoder.decode_raw([{:bytes, 32}, {:uint, 256}])

      %{root: root, timestamp: timestamp, eth_height: eth_height}
    end

    with {:ok, unfiltered_logs} <- get_ethereum_logs(block_from, block_to, event, contract),
         block_submissions <- unfiltered_logs |> filter_not_removed |> Enum.map(parse_block_submissions),
         do: {:ok, Enum.sort(block_submissions, &(&1.timestamp > &2.timestamp))}
  end

  defp encode_event_signature(signature) do
    # TODO: consider moving crypto to a umbrella app and use it across other apps
    # "consider" because `omisego_api` is now our "imported_by_all" app, and we're kind of "fine". To reevaluate
    signature |> :keccakf1600.sha3_256() |> Base.encode16(case: :lower)
  end

  defp int_to_hex(int), do: "0x" <> Integer.to_string(int, 16)

  defp filter_not_removed(logs) do
    logs |> Enum.filter(&(not Map.get(&1, "removed", true)))
  end

  defp get_ethereum_logs(block_from, block_to, event, contract) do
    try do
      Ethereumex.HttpClient.eth_get_logs(%{
        fromBlock: int_to_hex(block_from),
        toBlock: int_to_hex(block_to),
        address: contract,
        topics: ["0x#{event}"]
      })
    catch
      _ -> {:error, :failed_to_get_ethereum_events}
    end
  end

  @doc """
  Returns exits from a range of blocks. Collects exits from Ethereum logs.
  """
  def get_exits(block_from, block_to, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)
    event = encode_event_signature("ExitStarted(address,uint256,address,uint256)")

    parse_exit = fn %{"data" => "0x" <> exits} ->
      [owner, utxo_pos, token, amount] =
        exits
        |> Base.decode16!(case: :lower)
        |> ABI.TypeDecoder.decode_raw([:address, {:uint, 256}, :address, {:uint, 256}])

      {:ok, owner} = Crypto.encode_address(owner)

      %{owner: owner, utxo_pos: utxo_pos, amount: amount, token: token}
    end

    with {:ok, unfiltered_logs} <- get_ethereum_logs(block_from, block_to, event, contract),
         exits <- unfiltered_logs |> filter_not_removed |> Enum.map(parse_exit),
         do: {:ok, Enum.sort(exits, &(&1.block_height > &2.block_height))}
  end

  @doc """
  Returns exit for a specific utxo. Calls contract method.
  """
  def get_exit(utxo_pos, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)

    call_contract(contract, "getExit(uint256)", [utxo_pos], [:address, :address, {:uint, 256}])
  end

  def get_child_chain(blknum, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract_addr)

    call_contract(contract, "getChildChain(uint256)", [blknum], [{:bytes, 32}, {:uint, 256}])
  end

  defp call_contract_value(contract, signature) do
    with {:ok, values} <- call_contract(contract, signature, [], [{:uint, 256}]),
         {value} = values,
         do: {:ok, value}
  end

  def call_contract(contract, signature, args, return_types) do
    data = signature |> ABI.encode(args) |> Base.encode16()

    with {:ok, return} <- Ethereumex.HttpClient.eth_call(%{to: contract, data: "0x#{data}"}),
         "0x" <> enc_return = return,
         do: decode_answer(enc_return, return_types)
  end

  defp decode_answer(enc_return, return_types) do
    return =
      enc_return
      |> Base.decode16!(case: :lower)
      |> ABI.TypeDecoder.decode_raw(return_types)
      |> List.to_tuple()

    {:ok, return}
  end
end
