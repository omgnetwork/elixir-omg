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

  defmodule Transaction do
    @moduledoc """
    struct contain data required by submit block
    """
    defstruct [:root_hash, :nonce, :gas_price]
  end

  # , do: :ok
  def submit_block(
        %Transaction{root_hash: "0x" <> hash, nonce: nonce, gas_price: price},
        from \\ @omg_addr,
        contract \\ @contract
      ) do
    data =
      "submitBlock(bytes32,uint256)"
      |> ABI.encode([hash |> Base.decode16!(), nonce])
      |> Base.encode16()

    Ethereumex.HttpClient.eth_send_transaction(%{
      from: from,
      to: contract,
      data: "0x#{data}",
      gas: price
    })
  end

  # , do: {:ok, 12345678}
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

    Ethereumex.HttpClient.eth_call(%{
      to: contract,
      data: "0x#{data}"
    })
  end
end
