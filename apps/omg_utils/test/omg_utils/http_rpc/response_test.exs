# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.Utils.HttpRPC.ResponseTest do
  use ExUnit.Case, async: true

  alias OMG.Utils.HttpRPC.Response
  alias OMG.WatcherInfo.DB

  @cleaned_tx %{
    blknum: nil,
    sent_at: nil,
    txbytes: nil,
    txhash: nil,
    txindex: nil,
    metadata: nil
  }

  setup %{} do
    load_ecto()
    :ok
  end

  describe "test sanitization without ecto preloaded" do
    test "cleaning response: simple value list works without ecto loaded" do
      unload_ecto()
      value = [nil, 1, "01234", :atom, [], %{}, {:skip_hex_encode, "an arbitrary string"}]
      expected_value = [nil, 1, "0x3031323334", :atom, [], %{}, "an arbitrary string"]
      assert expected_value == Response.sanitize(value)
    end

    test "cleaning response structure: list of maps when ecto unloaded" do
      unload_ecto()
      refute [@cleaned_tx, @cleaned_tx] == Response.sanitize([%DB.Transaction{}, %DB.Transaction{}])
    end
  end

  test "cleaning response structure: map of maps" do
    assert %{first: @cleaned_tx, second: @cleaned_tx} ==
             Response.sanitize(%{second: %DB.Transaction{}, first: %DB.Transaction{}})
  end

  test "cleaning response structure: list of maps" do
    assert [@cleaned_tx, @cleaned_tx] == Response.sanitize([%DB.Transaction{}, %DB.Transaction{}])
  end

  test "cleaning response: simple value list" do
    value = [nil, 1, "01234", :atom, [], %{}, {:skip_hex_encode, "an arbitrary string"}]
    expected_value = [nil, 1, "0x3031323334", :atom, [], %{}, "an arbitrary string"]

    assert expected_value == Response.sanitize(value)
  end

  test "cleaning response: remove nested meta keys" do
    data =
      %{
        address: "0xd5b6e653beec1f8131d2ea4f574b2fd58770d9e0",
        utxos: [
          %{
            __meta__: %{context: nil, source: {nil, "txoutputs"}, state: :loaded},
            amount: 1,
            creating_deposit: "hash1",
            creating_transaction: nil,
            currency: String.duplicate("00", 20),
            deposit: %{
              __meta__: %{context: nil, source: {nil, "txoutputs"}, state: :loaded},
              blknum: 1,
              txindex: 0,
              event_type: :deposit,
              hash: "hash1"
            },
            id: 1
          }
        ]
      }
      |> Response.sanitize()

    assert false ==
             Enum.any?(
               hd(data.utxos).deposit,
               &match?({:__meta__, _}, &1)
             )
  end

  test "sanitize alarm types" do
    system_alarm = {:system_memory_high_watermark, []}
    system_disk_alarm = {{:disk_almost_full, "/dev/null"}, []}
    app_alarm = {:ethereum_connection_error, %{node: Node.self(), reporter: __MODULE__}}

    assert %{disk_almost_full: "/dev/null"} == Response.sanitize(system_disk_alarm)

    assert %{ethereum_connection_error: %{node: Node.self(), reporter: __MODULE__}} ==
             Response.sanitize(app_alarm)

    assert %{system_memory_high_watermark: []} == Response.sanitize(system_alarm)
  end

  test "skiping sanitize for specified keys" do
    # simplified EIP-712 structures serialization where
    # `types` should be skip entirely
    # `domain` sanitized partially
    # `message` fully sanitized

    address = <<124, 39, 109, 202, 171, 153, 189, 22, 22, 60, 27, 204, 230, 113, 202, 214, 161, 236, 9, 69>>
    address_hex = "0x7c276dcaab99bd16163c1bcce671cad6a1ec0945"
    zero20_hex = "0x" <> String.duplicate("00", 20)

    domain_spec = [
      %{name: "name", type: "string"},
      %{name: "verifyingContract", type: "address"},
      %{name: "chainId", type: "uint256"}
    ]

    domain_data = %{
      name: {:skip_hex_encode, "OMG Network"},
      verifyingContract: address,
      chainId: 32
    }

    message = %{
      input0: %{owner: address, currency: <<0::160>>, amount: 111}
    }

    typed_data = %{
      types: %{Eip712Domain: domain_spec},
      primaryType: "Transaction",
      domain: domain_data,
      message: message,

      # spicifies key to skip during sanitize
      skip_hex_encode: [:types, :primaryType, :non_existing]
    }

    response = Response.sanitize(typed_data)

    assert %{
             domain: %{name: "OMG Network", verifyingContract: ^address_hex, chainId: 32},
             message: %{
               input0: %{owner: ^address_hex, currency: ^zero20_hex, amount: 111}
             },
             primaryType: "Transaction",
             types: %{Eip712Domain: ^domain_spec}
           } = response

    # meta-key is removed from sanitized response
    assert response |> Map.get(:skip_hex_encode) |> is_nil()
  end

  describe "version/1" do
    test "returns a compliant semver when given an application" do
      # Using :elixir as the app because it is certain to be running during the test
      version = Response.version(:elixir)
      assert {:ok, _} = Version.parse(version)
    end
  end

  defp unload_ecto do
    :code.purge(Ecto)
    :code.delete(Ecto)
    false = :code.is_loaded(Ecto)
  end

  defp load_ecto, do: true = Code.ensure_loaded?(Ecto)
end
