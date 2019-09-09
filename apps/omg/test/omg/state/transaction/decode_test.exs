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

defmodule OMG.State.Transaction.DecodeTest do
  @moduledoc """
  This test the public-most APIs regarging the transaction, being mainly centered around:
    - recovery and stateless validation done in `Transaction.Recovered`
    - creation and encoding of raw transactions
    - some basic checks of internal APIs used elsewhere - getting inputs/outputs, spend authorization, hashing, encoding
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.State.Transaction

  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @transaction Transaction.Payment.new(
                 [{1, 1, 0}, {1, 2, 1}],
                 [{"alicealicealicealice", @eth, 1}, {"carolcarolcarolcarol", @eth, 2}],
                 <<0::256>>
               )

  describe "encoding/decoding is done properly" do
    test "Decode raw transaction, a low level encode/decode parity check" do
      {:ok, decoded} = @transaction |> Transaction.Extract.raw_txbytes() |> Transaction.Decode.it()
      assert decoded == @transaction
      assert decoded == @transaction |> Transaction.Extract.raw_txbytes() |> Transaction.Decode.it!()
    end
  end
end
