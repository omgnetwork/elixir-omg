defmodule OmiseGOWatcher.BlockValidator do
  @moduledoc false

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction

  @spec to_block(block :: map) :: {:ok, Block.t()}
  def to_block(%{"hash" => hash, "transactions" => transactions, "number" => number}) do
    {:ok,
     %Block{
       transactions:
         transactions
         |> Enum.map(&decode_transaction/1),
       hash: Base.decode16!(hash),
       number: number
     }}
  end

  defp decode_transaction(signed_tx_bytes) do
    {:ok, transaction} = Transaction.Signed.decode(decode(signed_tx_bytes))
    transaction
  end

  defp decode(nil), do: nil
  defp decode(value), do: Base.decode16!(value)
end
