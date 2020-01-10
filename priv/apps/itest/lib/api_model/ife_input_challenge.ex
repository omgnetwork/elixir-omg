defmodule Itest.ApiModel.IfeInputChallenge do
  @moduledoc """
  The IFE ExitData payload structure
  """

  defstruct [
    :in_flight_txbytes,
    :in_flight_input_index,
    :spending_txbytes,
    :spending_input_index,
    :spending_sig,
    :input_tx,
    :input_utxo_pos
  ]

  @type t() :: %__MODULE__{
          in_flight_txbytes: binary(),
          in_flight_input_index: non_neg_integer(),
          spending_txbytes: binary(),
          spending_input_index: non_neg_integer(),
          spending_sig: binary(),
          input_tx: binary(),
          input_utxo_pos: non_neg_integer()
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
    is_binary(struct.in_flight_txbytes) &&
      is_integer(struct.in_flight_input_index) &&
      is_binary(struct.spending_txbytes) &&
      is_integer(struct.spending_input_index) &&
      is_binary(struct.spending_sig) &&
      is_binary(struct.input_tx) &&
      is_integer(struct.input_utxo_pos)
  end
end
