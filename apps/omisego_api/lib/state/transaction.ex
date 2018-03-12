defmodule OmiseGO.API.State.Transaction do
  @moduledoc """
  Internal representation of a spend transaction on Plasma chain
  """

  @zero_address <<0>> |> List.duplicate(20) |> Enum.join

  # TODO: probably useful to structure these fields somehow ore readable like
  # defstruct [:input1, :input2, :output1, :output2, :fee], with in/outputs as structs or tuples?
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

  defmodule Signed do
    @moduledoc false
    defstruct [:raw_tx, :sig1, :sig2]
  end

  defmodule Recovered do
    @moduledoc """
    Representation of a Signed transaction, with addresses recovered from signatures (from Transaction.Signed)
    Intent is to allow concurent processing of signatures outside of serial processing in state.ex
    """

    # FIXME: refactor to somewhere to avoid dupliaction
    @zero_address <<0>> |> List.duplicate(20) |> Enum.join

    # FIXME: rethink default values
    defstruct [:raw_tx, spender1: @zero_address, spender2: @zero_address]
  end

  # TODO: add convenience function for creating common transactions (1in-1out, 1in-2out-with-change, etc.)

  def zero_address, do: @zero_address

end
