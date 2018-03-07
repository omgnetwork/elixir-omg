defmodule OmiseGO.API.State.Transaction do

  @zero_address List.duplicate(<<0>>, 20) |> Enum.join

  defstruct [:blknum1,
             :txindex1,
             :oindex1,
             :blknum2,
             :txindex2,
             :oindex2,
             :newowner1,
             :amount1,
             :newowner2,
             :amount2,
             :fee,
             ]

  defmodule Recovered do

    # FIXME: refactor to somewhere to avoid dupliaction
    @zero_address List.duplicate(<<0>>, 20) |> Enum.join

    # FIXME: rethink default values
    defstruct [:raw_tx, spender1: @zero_address, spender2: @zero_address]
  end

  defmodule Signed do
    defstruct [:raw_tx, :sig1, :sig2]
  end

  def new_deposit(owner, amount) do
    %__MODULE__{zero_transaction | newowner1: owner, amount1: amount, newowner2: @zero_address}
  end

  def zero_address, do: @zero_address

  defp zero_transaction do
    # FIXME: rethink what would be the best approach to default values here
    %__MODULE__{
      blknum1: 0, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
      amount1: 0, amount2: 0, fee: 0,
    }
  end

end
