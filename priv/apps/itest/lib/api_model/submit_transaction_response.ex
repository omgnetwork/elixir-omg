defmodule Itest.ApiModel.SubmitTransactionResponse do
  @moduledoc false
  defstruct [:blknum, :txhash, :txindex]

  @type t() :: %__MODULE__{
          blknum: pos_integer(),
          txhash: binary(),
          txindex: non_neg_integer()
        }
end
