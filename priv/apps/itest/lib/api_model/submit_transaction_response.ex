defmodule Itest.ApiModel.SubmitTransactionResponse do
  @moduledoc false
  defstruct [:blknum, :txhash, :txindex]

  @type t() :: %__MODULE__{
          blknum: pos_integer(),
          txhash: binary(),
          txindex: non_neg_integer()
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
    is_integer(struct.blknum) &&
      is_binary(struct.txhash) &&
      is_integer(struct.txindex)
  end
end
