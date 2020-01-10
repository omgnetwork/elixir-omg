defmodule Itest.ApiModel.IfeExits do
  @moduledoc """
  The IFE Exits
  """

  defstruct [
    :is_canonical,
    :exit_start_timestamp,
    :exit_map,
    :position,
    :bond_owner,
    :bond_size,
    :oldest_competitor_position
  ]

  @type t() :: %__MODULE__{
          is_canonical: boolean(),
          exit_start_timestamp: non_neg_integer(),
          exit_map: non_neg_integer(),
          position: non_neg_integer(),
          bond_owner: binary(),
          bond_size: non_neg_integer(),
          oldest_competitor_position: non_neg_integer()
        }

  def to_struct(values, attrs) do
    to_struct(values, attrs, struct(__MODULE__))
  end

  def to_struct([], [], result) do
    true = is_valid(result)
    result
  end

  def to_struct([value | values], [attr | attrs], struct) do
    to_struct(values, attrs, Map.put(struct, attr, value))
  end

  defp is_valid(struct) do
    is_boolean(struct.is_canonical) &&
      is_integer(struct.exit_start_timestamp) &&
      is_integer(struct.exit_map) &&
      is_integer(struct.position) &&
      is_binary(struct.bond_owner) &&
      is_integer(struct.bond_size) &&
      is_integer(struct.oldest_competitor_position)
  end
end
