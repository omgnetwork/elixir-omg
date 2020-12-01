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

defmodule OMG.Utils.HttpRPC.EncodingTest do
  use ExUnit.Case, async: true

  alias OMG.Utils.HttpRPC.Encoding

  test "decodes all up/down/mixed case values" do
    assert [{:ok, <<222, 173, 190, 239>>}, {:ok, <<222, 173, 190, 239>>}, {:ok, <<222, 173, 190, 239>>}] ==
             Enum.map(["0xdeadbeef", "0xDEADBEEF", "0xDeadBeeF"], &Encoding.from_hex/1)
  end

  test "doesn't decode hex without '0x' prefix" do
    assert {:error, :invalid_hex} == Encoding.from_hex("deadbeef")
  end

  test "encodes stuff" do
    assert "0xdeadbeef" == Encoding.to_hex(<<222, 173, 190, 239>>)
  end
end
