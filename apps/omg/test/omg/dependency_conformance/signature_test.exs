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

defmodule OMG.DependencyConformance.SignatureTest do
  @moduledoc """
  Tests that EIP-712-compliant signatures generated `somehow` (via Elixir code as it happens) are treated the same
  by both Elixir signature code and contract signature code.
  """

  alias OMG.DevCrypto
  alias OMG.Eth
  alias OMG.State.Transaction
  alias OMG.TestHelper
  alias Support.Deployer
  alias Support.DevNode

  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :common

  @alice %{
    addr: <<215, 32, 17, 47, 111, 72, 20, 47, 149, 226, 138, 242, 35, 254, 141, 212, 16, 22, 155, 182>>,
    priv:
      <<170, 145, 170, 111, 112, 29, 60, 152, 73, 136, 133, 220, 101, 57, 32, 144, 174, 192, 102, 193, 186, 145, 231,
        104, 132, 231, 27, 63, 128, 36, 204, 94>>
  }
  @bob %{
    addr: <<141, 246, 138, 77, 76, 3, 78, 54, 173, 40, 234, 195, 29, 170, 154, 64, 99, 14, 118, 139>>,
    priv:
      <<6, 31, 86, 177, 209, 153, 18, 204, 55, 88, 137, 149, 48, 164, 92, 147, 255, 58, 163, 80, 243, 202, 105, 56, 176,
        216, 149, 207, 188, 96, 160, 87>>
  }
  @eth OMG.Eth.RootChain.eth_pseudo_address()
  @token <<235, 169, 32, 193, 242, 237, 159, 137, 184, 46, 124, 13, 178, 171, 61, 87, 179, 179, 135, 146>>

  setup %{} do
    vcr_path = Path.join(__DIR__, "../../fixtures/vcr_cassettes")
    ExVCR.Config.cassette_library_dir(vcr_path)

    :ok
  end

  setup_all do
    %{plasma_framework: plasma_framework} = Application.get_env(:omg_eth, :contract_addr)
    # signtest_addr was recorded with exvcr
    signtest_addr = <<25, 146, 92, 198, 69, 114, 15, 187, 97, 247, 99, 4, 238, 21, 80, 30, 49, 151, 243, 169>>
    :ok = Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: Eth.Encoding.to_hex(signtest_addr)})

    on_exit(fn ->
      # reverting to the original values from `omg_eth/config/test.exs`
      Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: plasma_framework})
    end)

    [contract: signtest_addr]
  end

  test "signature with empty transaction", context do
    use_cassette "712_eip_mock/empty_transaction", match_requests_on: [:request_body] do
      contract = context[:contract]
      tx = TestHelper.create_signed([], [])
      verify(contract, tx)
    end
  end

  test "signature with no inputs", context do
    use_cassette "712_eip_mock/no_inputs", match_requests_on: [:request_body] do
      contract = context[:contract]
      tx = TestHelper.create_signed([], [{@alice, @eth, 100}])
      verify(contract, tx)
    end
  end

  test "signature with no outputs", context do
    use_cassette "712_eip_mock/no_outputs", match_requests_on: [:request_body] do
      contract = context[:contract]
      tx = TestHelper.create_signed([{1, 0, 0, @alice}], [])
      verify(contract, tx)
    end
  end

  test "signature for small tx", context do
    use_cassette "712_eip_mock/small_tx", match_requests_on: [:request_body] do
      contract = context[:contract]
      tx = TestHelper.create_signed([{1, 0, 0, @alice}], [{@alice, @eth, 100}])
      verify(contract, tx)
    end
  end

  test "signature for full tx", context do
    use_cassette "712_eip_mock/transaction", match_requests_on: [:request_body] do
      contract = context[:contract]

      tx =
        TestHelper.create_signed(
          [{1, 0, 0, @alice}, {1000, 555, 3, @bob}, {2000, 333, 1, @alice}, {15_015, 0, 0, @bob}],
          [{@alice, @eth, 100}, {@alice, @token, 50}, {@bob, @token, 75}, {@bob, @eth, 25}]
        )

      verify(contract, tx)
    end
  end

  test "signature for a transaction with metadata", context do
    use_cassette "712_eip_mock/transaction_metadata", match_requests_on: [:request_body] do
      contract = context[:contract]
      # metadata gets a random 256 binary assigned
      <<_::256>> =
        metadata =
        <<136, 72, 182, 143, 114, 106, 162, 12, 23, 115, 79, 191, 109, 221, 32, 179, 148, 78, 39, 106, 255, 9, 104, 243,
          72, 204, 153, 10, 16, 140, 95, 27>>

      tx =
        TestHelper.create_signed(
          [{1, 0, 0, @alice}, {1000, 555, 3, @bob}, {2000, 333, 1, @alice}, {15_015, 0, 0, @bob}],
          @eth,
          [{@alice, 100}, {@alice, 50}, {@bob, 75}, {@bob, 25}],
          metadata
        )

      verify(contract, tx)
    end
  end

  defp verify(contract, %Transaction.Signed{raw_tx: tx}) do
    {:ok, solidity_hash} =
      Eth.call_contract(contract, "hashTx(address,bytes)", [contract, Transaction.raw_txbytes(tx)], [{:bytes, 32}])

    assert solidity_hash == OMG.TypedDataHash.hash_struct(tx)
  end
end
