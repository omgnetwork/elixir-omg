defmodule Itest.ApiModel.IfeExitData do
  @moduledoc """
  The IFE ExitData payload structure
  """

  defstruct [:in_flight_tx, :in_flight_tx_sigs, :input_txs_inclusion_proofs, :input_utxos_pos, :input_txs]

  @type t() :: %__MODULE__{
          in_flight_tx: binary(),
          in_flight_tx_sigs: list(binary()),
          input_txs: list(binary()),
          input_txs_inclusion_proofs: list(binary()),
          input_utxos_pos: list(non_neg_integer())
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
    is_binary(struct.in_flight_tx) &&
      is_list(struct.in_flight_tx_sigs) &&
      is_list(struct.input_txs) &&
      is_list(struct.input_txs_inclusion_proofs) &&
      is_list(struct.input_utxos_pos)
  end
end
