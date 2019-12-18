defmodule Itest.Transactions.Deposit do
  @moduledoc false
  alias Itest.Transactions.Encoding

  @zero_metadata <<0::256>>
  @output_type 1

  defstruct [:inputs, :outputs, metadata: @zero_metadata]

  @type t() :: %__MODULE__{
          inputs: list(InputPointer.t()),
          outputs: list(Output.FungibleMoreVPToken.t()),
          metadata: Transaction.metadata()
        }

  def new(owner, currency, amount) do
    outputs = [
      [@output_type, [Encoding.to_binary(owner), currency, amount]]
    ]

    %__MODULE__{inputs: [], outputs: outputs, metadata: @zero_metadata}
  end
end
