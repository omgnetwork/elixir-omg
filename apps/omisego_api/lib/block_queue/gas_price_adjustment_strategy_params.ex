defmodule OmiseGO.API.BlockQueue.GasPriceAdjustmentStrategyParams do
  @moduledoc """
  Encapsulates the Eth gas price adjustment strategy parameters into its own structure
  """

  defstruct queue_length_when_raising: 2,
            gas_price_lowering_factor: 0.9,
            gas_price_raising_factor: 2.0

  @type t() :: %__MODULE__{
          # minimum blocks queue length that gas price will be raised
          queue_length_when_raising: pos_integer(),
          # the factor the gas price will be decreased by
          gas_price_lowering_factor: float(),
          # the factor the gas price will be increased by
          gas_price_raising_factor: float()
        }

  def new(raising_factor, lowering_factor, raising_queue_length \\ 2) do
    %__MODULE__{
      gas_price_raising_factor: raising_factor,
      gas_price_lowering_factor: lowering_factor,
      queue_length_when_raising: raising_queue_length
    }
  end
end
