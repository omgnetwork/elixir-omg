defmodule OmiseGO.API.UtxoPositionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias OmiseGO.API.UtxoPosition

  test "encode and decode the utxo position checking" do
    decoded = UtxoPosition.new(4, 5, 1)
    assert 4_000_050_001 = encoded = UtxoPosition.encode(decoded)
    assert decoded == UtxoPosition.decode(encoded)
  end
end
