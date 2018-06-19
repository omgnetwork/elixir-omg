defmodule OmiseGOWatcher.BlockValidator do
  @moduledoc false

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.Transaction

  @spec json_to_block(block :: map) :: {:ok, Block.t()} | {:error, :incorrect_hash}
  def json_to_block(%{"hash" => hash, "transactions" => transactions, "number" => number}) do
    with block <- %Block{transactions: transactions |> Enum.map(&decode_transaction/1), number: number},
         %Block{hash: calculate_hash} = block_with_hash <- Block.merkle_hash(block) do
      if calculate_hash == Base.decode16!(hash), do: {:ok, block_with_hash}, else: {:error, :incorrect_hash}
    end
  end

  defp decode_transaction(signed_tx_bytes) do
    with {:ok, transaction_sign} <- Transaction.Signed.decode(decode(signed_tx_bytes)),
         {:ok, transaction_recovered} <- Transaction.Recovered.recover_from(transaction_sign) do
      transaction_recovered
    end
  end

  defp decode(nil), do: nil
  defp decode(value), do: Base.decode16!(value)
end
