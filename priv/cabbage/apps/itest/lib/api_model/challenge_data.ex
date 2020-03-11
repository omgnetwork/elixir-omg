defmodule Itest.ApiModel.ChallengeData do
  @moduledoc """
  The purpose of this module is to represent a specific API response as a struct and validates it's response and validates it's response
  """

  defstruct [:exit_id, :exiting_tx, :input_index, :sig, :txbytes]

  @type t() :: %__MODULE__{
          exit_id: pos_integer(),
          exiting_tx: binary(),
          input_index: non_neg_integer(),
          sig: binary(),
          txbytes: binary
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
    is_integer(struct.exit_id) &&
      is_binary(struct.exiting_tx) &&
      is_integer(struct.input_index) &&
      is_binary(struct.sig) &&
      is_binary(struct.txbytes)
  end
end
