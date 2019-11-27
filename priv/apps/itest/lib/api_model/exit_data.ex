defmodule Itest.ApiModel.ExitData do
  @moduledoc """
  The ExitData payload structure
  """

  defstruct [:proof, :utxo_pos, :txbytes]

  @type t() :: %__MODULE__{
          # outputTxInclusionProof
          proof: String.t(),
          # rlpOutputTx
          txbytes: String.t(),
          # utxoPos
          utxo_pos: non_neg_integer()
        }
end
