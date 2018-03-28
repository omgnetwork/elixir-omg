defmodule OmiseGO.Eth do
  @moduledoc """
  Adapter/port to ethereum
  """

  @contract Application.get_env(:omisego_eth, :contract)
  @omg_addr Application.get_env(:omisego_eth, :omg_addr)

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

  def submit_block(
        %BlockSubmission{hash: hash, nonce: nonce, gas_price: gas_price},
        from \\ @omg_addr,
        contract \\ @contract
      ) do
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
      nonce: encode_eth_rpc_unsigned_int(nonce),
    })
  end

  defp encode_eth_rpc_unsigned_int(value) do
    "0x" <> (value |> :binary.encode_unsigned |> Base.encode16 |> String.trim_leading("0"))
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

  def get_current_child_block(contract \\ @contract) do
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

  def get_child_chain(block_number, contract \\ @contract) do
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
  def get_deposits(block_from, block_to, contract \\ @contract) do
    event = encode_event_signature("Deposit(address,uint256,uint256)")

    parse_deposit =
      fn "0x" <> deposit ->
        [owner, amount, block_height] =
          deposit
          |> Base.decode16!(case: :lower)
          |> ABI.TypeDecoder.decode_raw([:address, {:uint, 256}, {:uint, 256}])
        owner = "0x" <> Base.encode16(owner, case: :lower)
        %{owner: owner, amount: amount, block_height: block_height}
      end

    with {:ok, unfiltered_logs} <- get_ethereum_logs(block_from, block_to, event, contract),
         deposits <- get_logs(unfiltered_logs, parse_deposit),
         do: {:ok, Enum.sort(deposits, &(&1.block_height > &2.block_height))}
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
      _ -> {:error, :failed_to_get_deposits}
    end
  end
end
