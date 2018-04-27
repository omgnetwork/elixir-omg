defmodule OmiseGO.Eth do
  @moduledoc """
  Adapter/port to ethereum
  """
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}

  @block_offset 1_000_000_000
  @transaction_offset 10_000

  def geth do
    _ = Application.ensure_all_started(:porcelain)
    _ = Application.ensure_all_started(:ethereumex)
    {ref, geth_os_pid, _} = OmiseGO.Eth.Geth.start()

    on_exit = fn ->
      OmiseGO.Eth.Geth.stop(ref, geth_os_pid)
    end

    {:ok, on_exit}
  end

  defmodule BlockSubmission do
    @moduledoc false

    @type hash() :: <<_::256>>
    @type plasma_block_num() :: pos_integer()

    @type t() :: %{
            num: plasma_block_num(),
            hash: hash(),
            nonce: non_neg_integer(),
            gas_price: pos_integer()
          }
    defstruct [:num, :hash, :nonce, :gas_price]
  end

  @spec get_root_deployment_height(binary() | nil, binary() | nil) ::
          {:ok, integer()} | Ethereumex.HttpClient.error()
  def get_root_deployment_height(txhash \\ nil, contract \\ nil) do

    contract = contract || Application.get_env(:omisego_eth, :contract)
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

  def submit_block(
        %BlockSubmission{hash: hash, nonce: nonce, gas_price: gas_price},
        from \\ nil,
        contract \\ nil
      ) do
    contract = contract || Application.get_env(:omisego_eth, :contract)
    from = from || Application.get_env(:omisego_eth, :omg_addr)

    data =
      "submitBlock(bytes32)"
      |> ABI.encode([hash |> Base.decode16!()])
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

  def deposit(value, gas_price, from \\ nil, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract)
    from = from || Application.get_env(:omisego_eth, :omg_addr)

    data =
      "deposit()"
      |> ABI.encode([])
      |> Base.encode16()

    gas = 100_000

    Ethereumex.HttpClient.eth_send_transaction(%{
      from: from,
      to: contract,
      data: "0x#{data}",
      gas: encode_eth_rpc_unsigned_int(gas),
      gasPrice: encode_eth_rpc_unsigned_int(gas_price),
      value: encode_eth_rpc_unsigned_int(value)
    })

  end

  def start_deposit_exit(deposit_positon, value, gas_price, from \\ nil, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract)
    from = from || Application.get_env(:omisego_eth, :omg_addr)

    data =
      "startDepositExit(uint256,uint256)"
      |> ABI.encode([deposit_positon, value])
      |> Base.encode16()

    gas = 100_0000

    Ethereumex.HttpClient.eth_send_transaction(%{
      from: from,
      to: contract,
      data: "0x#{data}",
      gas: encode_eth_rpc_unsigned_int(gas),
      gasPrice: encode_eth_rpc_unsigned_int(gas_price)
    })

  end
  
  def start_exit(utxo_position, proof, %Transaction.Signed{raw_tx: raw_tx, sig1: sig1, sig2: sig2}, gas_price, from \\ nil, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract)
    from = from || Application.get_env(:omisego_eth, :omg_addr)

    data =
      "startExit(uint256,bytes,bytes,bytes)"
      |> ABI.encode([utxo_position, raw_tx, proof, sig1 <> sig2 ])
      |> Base.encode16()

    gas = 100_0000

    Ethereumex.HttpClient.eth_send_transaction(%{
      from: from,
      to: contract,
      data: "0x#{data}",
      gas: encode_eth_rpc_unsigned_int(gas),
      gasPrice: encode_eth_rpc_unsigned_int(gas_price)
    })

  end

  defp encode_eth_rpc_unsigned_int(value) do
    "0x" <> (value |> :binary.encode_unsigned() |> Base.encode16() |> String.trim_leading("0"))
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

  def get_current_child_block(contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract)

    data = "currentChildBlock()" |> ABI.encode([]) |> Base.encode16()

    {:ok, "0x" <> enc_return} =
      Ethereumex.HttpClient.eth_call(%{
        to: contract,
        data: "0x#{data}"
      })

    [child_block] =
      enc_return |> Base.decode16!(case: :lower) |> ABI.TypeDecoder.decode_raw([{:uint, 256}])

    {:ok, child_block}
  end

  def get_child_chain(block_number, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract)

    data = "getChildChain(uint256)" |> ABI.encode([block_number]) |> Base.encode16()

    {:ok, "0x" <> enc_return} =
      Ethereumex.HttpClient.eth_call(%{
        to: contract,
        data: "0x#{data}"
      })

    [{root, created_at}] =
      enc_return
      |> Base.decode16!(case: :lower)
      |> ABI.TypeDecoder.decode_raw([{:tuple, [:bytes32, {:uint, 256}]}])

    {:ok, {root, created_at}}
  end

  @doc """
  Returns lists of deposits sorted by child chain block number
  """
  def get_deposits(block_from, block_to, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract)

    event = encode_event_signature("Deposit(address,uint256,uint256)")

    parse_deposit =
      fn "0x" <> deposit ->
        [owner, amount, blknum] =
          deposit
          |> Base.decode16!(case: :lower)
          |> ABI.TypeDecoder.decode_raw([:address, {:uint, 256}, {:uint, 256}])
        owner = "0x" <> Base.encode16(owner, case: :lower)
        %{owner: owner, amount: amount, blknum: blknum}
      end

    with {:ok, unfiltered_logs} <- get_ethereum_logs(block_from, block_to, event, contract),
         deposits <- get_logs(unfiltered_logs, parse_deposit),
         do: {:ok, Enum.sort(deposits, &(&1.blknum > &2.blknum))}
  end

  defp encode_event_signature(signature) do
    #TODO: move crypto to a umbrella app and use it across other apps
    signature |> :keccakf1600.sha3_256() |> Base.encode16(case: :lower)
  end

  defp int_to_hex(int), do: "0x" <> Integer.to_string(int, 16)

  defp get_logs(logs, parse_log) do
    logs
    |> Enum.filter(&(not Map.get(&1, "removed", true)))
    |> Enum.map(&(Map.get(&1, "data")))
    |> Enum.map(parse_log)
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
  Returns lists of deposits sorted by child chain block number
  """
  def get_exits(block_from, block_to, contract \\ nil) do
    contract = contract || Application.get_env(:omisego_eth, :contract)

    event = encode_event_signature("Exit(address,uint256)")
    parse_exit =
      fn "0x" <> deposit ->
        [owner, utxo_position] =
          deposit
          |> Base.decode16!(case: :lower)
          |> ABI.TypeDecoder.decode_raw([:address, {:uint, 256}])
        owner = "0x" <> Base.encode16(owner, case: :lower)
        blknum = div(utxo_position, @block_offset)
        txindex = utxo_position |> rem(@block_offset) |> div(@transaction_offset)
        oindex = utxo_position - blknum * @block_offset - txindex * @transaction_offset
        %{owner: owner, blknum: blknum, txindex: txindex, oindex: oindex}
      end

    with {:ok, unfiltered_logs} <- get_ethereum_logs(block_from, block_to, event, contract),
         exits <- get_logs(unfiltered_logs, parse_exit),
         do: {:ok, Enum.sort(exits, &(&1.block_height > &2.block_height))}
  end
end
