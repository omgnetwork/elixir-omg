defmodule Itest.ApiModel.Utxo do
  @moduledoc false
  defstruct [:amount, :blknum, :currency, :oindex, :owner, :txindex, :utxo_pos]

  @type t() :: %__MODULE__{
          amount: non_neg_integer(),
          blknum: pos_integer(),
          currency: binary(),
          oindex: non_neg_integer(),
          owner: binary(),
          txindex: non_neg_integer(),
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
    is_integer(struct.amount) && is_integer(struct.blknum) &&
      is_binary(struct.currency) &&
      is_integer(struct.oindex) && is_binary(struct.owner) &&
      is_integer(struct.txindex) && is_integer(struct.utxo_pos)
  end
end
