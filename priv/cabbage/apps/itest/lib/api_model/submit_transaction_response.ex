defmodule Itest.ApiModel.SubmitTransactionResponse do
  @moduledoc """
  The purpose of this module is to represent a specific API response as a struct and validates it's response
  """

  require Logger

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

    :ok =
      case is_valid(result) do
        false ->
          _ = Logger.warn("Transaction response came as #{inspect(attrs)}")
          false

        true ->
          :ok
      end

    result
  end

  defp is_valid(struct) do
    is_integer(struct.blknum) &&
      is_binary(struct.txhash) &&
      is_integer(struct.txindex)
  end
end
