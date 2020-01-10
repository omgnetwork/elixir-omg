defmodule Itest.ApiModel.IfeOutputChallenge do
  @moduledoc """
  The IFE ExitData payload structure
  """

  defstruct [
    :in_flight_txbytes,
    :in_flight_output_pos,
    :spending_txbytes,
    :spending_input_index,
    :spending_sig,
    :in_flight_proof
  ]

  @type t() :: %__MODULE__{
          in_flight_txbytes: binary(),
          spending_txbytes: binary(),
          spending_input_index: non_neg_integer(),
          spending_sig: binary(),
          in_flight_proof: binary()
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
      is_integer(struct.in_flight_output_pos) &&
      is_binary(struct.spending_txbytes) &&
      is_integer(struct.spending_input_index) &&
      is_binary(struct.spending_sig) &&
      is_binary(struct.in_flight_proof)
  end
end
