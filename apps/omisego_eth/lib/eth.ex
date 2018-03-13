defmodule OmiseGO.Eth do
  @moduledoc """
  Adapter/port to ethereum
  """

  defmodule Transaction do
    defstruct [:root_hash, :nonce, :gas_price]
  end

  def submit_block(%Transaction{ root_hash: hash, nonce: nonce , gas_price: price}) do#, do: :ok
    data  = "submitBlock(bytes32,uint256)"
        |> ABI.encode([hash,nonce])
        |> Base.encode16
    Ethereumex.HttpClient.eth_send_transaction(%{
      from:  Application.get_env(:omisego_eth, :contract)
      data: data
       gas: price
    })
  end

  def get_ethereum_height do#, do: {:ok, 12345678}
    result = Ethereumex.HttpClient.eth_block_number()
  end

  def get_current_child_block do
     data = "currentChildBlock()" | ABI.encode(args) |> Base.encode16
     {:ok, "0x" <> enc_return} = Ethereumex.HttpClient.eth_call(%{
       to: Application.get_env(:omisego_eth,:contract)
       data:"0x#{data}"
       })
     {:ok, enc_return |> Base.decode16!(case: :lower) |> ABI.TypeDecoder.decode_raw([{:uint, 256}])}
  end
end
