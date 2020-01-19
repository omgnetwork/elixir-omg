defmodule Itest.ApiModel.IfeCompetitor do
  @moduledoc """
  The ExitData payload structure
  """

  defstruct [
    :competing_input_index,
    :competing_proof,
    :competing_sig,
    :competing_tx_pos,
    :competing_txbytes,
    :in_flight_input_index,
    :in_flight_txbytes,
    :input_tx,
    :input_utxo_pos
  ]

  @type t() :: %__MODULE__{
          competing_input_index: integer(),
          competing_proof: binary(),
          competing_sig: binary(),
          competing_tx_pos: integer(),
          competing_txbytes: binary(),
          in_flight_input_index: integer(),
          in_flight_txbytes: binary(),
          input_tx: binary(),
          input_utxo_pos: integer()
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
    is_integer(struct.competing_input_index) &&
      is_binary(struct.competing_proof) &&
      is_binary(struct.competing_sig) &&
      is_integer(struct.competing_tx_pos) &&
      is_binary(struct.competing_txbytes) &&
      is_integer(struct.in_flight_input_index) &&
      is_binary(struct.in_flight_txbytes) &&
      is_binary(struct.input_tx) &&
      is_integer(struct.input_utxo_pos)
  end
end
