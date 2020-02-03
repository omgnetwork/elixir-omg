defmodule Itest.ApiModel.WatcherSecurityCriticalConfiguration do
  @moduledoc """
  The purpose of this module is to represent a specific API response as a struct and validates it's response
  """
  defstruct [:contract_semver, :deposit_finality_margin, :network, :exit_processor_sla_margin]

  @type t() :: %__MODULE__{
          deposit_finality_margin: non_neg_integer(),
          contract_semver: binary(),
          network: binary(),
          exit_processor_sla_margin: non_neg_integer()
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
    is_integer(struct.deposit_finality_margin) &&
      is_binary(struct.contract_semver) &&
      is_integer(struct.exit_processor_sla_margin) &&
      is_binary(struct.network)
  end
end
