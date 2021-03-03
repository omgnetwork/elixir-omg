# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.State.Transaction.WitnessTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias OMG.Watcher.State.Transaction.Witness

  describe "valid?/1" do
    test "returns true when is binary and 65 bytes long" do
      assert Witness.valid?(<<0::520>>)
    end

    test "returns false when not a binary" do
      refute Witness.valid?([<<0>>])
    end

    test "returns false when not 65 bytes long" do
      refute Witness.valid?(<<0>>)
    end
  end
end
