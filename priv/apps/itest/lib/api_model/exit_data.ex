defmodule Itest.ApiModel.ExitData do
  @moduledoc """
  The ExitData payload structure
  """

  defstruct [:proof, :utxo_pos, :txbytes]

  @type t() :: %__MODULE__{
          # outputTxInclusionProof
          proof: binary(),
          # rlpOutputTx
          txbytes: binary(),
          # utxoPos
          utxo_pos: non_neg_integer()
        }

  def to_struct(attrs) do
    struct = struct(__MODULE__)

    result =
      Enum.reduce(Map.to_list(struct), struct, fn {k, _}, acc ->
        case Map.fetch(attrs, Atom.to_string(k)) do
          {:ok, v} -> %{acc | k => v}
          :error -> acc
        end
      end)

    true = is_valid(result)
    result
  end

  defp is_valid(struct) do
    is_binary(struct.proof) &&
      is_binary(struct.txbytes) &&
      is_integer(struct.utxo_pos)
  end
end
