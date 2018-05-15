defmodule OmiseGOWatcher.Validator do
  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction

  @spec json_to_block(block :: map, number :: integer) :: {:ok, Block.t()}
  def json_to_block(%{"hash" => hash, "transactions" => transactions}, number) do
    {:ok,
     %Block{
       transactions:
         transactions
         |> Enum.map(&decode_transaction/1),#&Transaction.Signed.decode(Base.decode16!(&1))),
       hash: Base.decode16!(hash),
       number: number
     }}

    # Enum.map(&decode_transaction/1), hash: Base.decode16!(hash)}}
  end

  defp decode_transaction(line) do
    {:ok, transaction} = Transaction.Signed.decode(decode(line))
    transaction
  end

  defp decode(nil), do: nil
  defp decode(value), do: Base.decode16!(value)
end
