defmodule OmiseGO.API.UtxoPositionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias OmiseGO.API.UtxoPosition

  test "encode_utxo_position checking for diffrent agruments" do
    assert 4_000_050_001 == UtxoPosition.encode_utxo_position(%UtxoPosition{blknum: 4, txindex: 5, oindex: 1})
  end

  test "decode_utxo_position checking for diffrent agruments" do
    assert %UtxoPosition{blknum: 4, txindex: 5, oindex: 1} == UtxoPosition.decode_utxo_position(4_000_050_001)
  end
end
