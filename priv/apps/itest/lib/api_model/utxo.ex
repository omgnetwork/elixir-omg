defmodule Itest.ApiModel.Utxo do
  @moduledoc false
  defstruct [:amount, :blknum, :currency, :oindex, :owner, :txindex, :utxo_pos]

  @type t() :: %__MODULE__{
          amount: non_neg_integer(),
          blknum: pos_integer(),
          currency: binary(),
          oindex: non_neg_integer(),
          owner: binary(),
          txindex: non_neg_integer(),
          utxo_pos: non_neg_integer()
        }
end
