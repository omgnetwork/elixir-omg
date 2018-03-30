defmodule OmiseGO.Eth do
  @moduledoc """
  Adapter/port to ethereum
  """

  @contract Application.get_env(:omisego_eth, :contract)
  @omg_addr Application.get_env(:omisego_eth, :omg_addr)
  @txhash_contract Application.get_env(:omisego_eth, :txhash_contract)

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

  @spec get_root_deployment_height(binary(), binary()) ::
          {:ok, integer()} | Ethereumex.HttpClient.error()
  def get_root_deployment_height(txhash \\ @txhash_contract, contract \\ @contract) do
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
        %BlockSubmission{num: child_block_number, hash: hash, nonce: nonce, gas_price: gas_price},
        from \\ @omg_addr,
        contract \\ @contract
      ) do
    data =
      "submitBlock(bytes32,uint256)"
      |> ABI.encode([hash |> Base.decode16!(), child_block_number])
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
end
