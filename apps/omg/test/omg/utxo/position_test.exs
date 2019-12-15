# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Utxo.PositionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias OMG.Utxo
  require Utxo

  test "decode the utxo position checking" do
    encoded = 4_000_050_001
    decoded = {:utxo_position, 4, 5, 1}
    assert decoded == Utxo.Position.decode!(encoded)
    assert {:ok, decoded} == Utxo.Position.decode(encoded)
  end

  test "verbose error on too low encoded position" do
    assert {:error, :encoded_utxo_position_too_low} = Utxo.Position.decode(0)
    assert {:error, :encoded_utxo_position_too_low} = Utxo.Position.decode(-1)
  end

  test "too low encoded position means non positive only" do
    assert {:ok, Utxo.position(0, 0, 1)} = Utxo.Position.decode(1)
  end
end
