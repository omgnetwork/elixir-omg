defmodule OmiseGO.API.Utxo.PositionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias OmiseGO.API.Utxo
  require Utxo

  test "encode and decode the utxo position checking" do
    decoded = Utxo.position(4, 5, 1)
    assert 4_000_050_001 = encoded = Utxo.Position.encode(decoded)
    assert decoded == Utxo.Position.decode(encoded)
  end
end
