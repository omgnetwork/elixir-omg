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

defmodule OMG.WatcherInfo.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.Fixtures

  alias OMG.Eth
  alias OMG.Utxo
  alias OMG.WatcherInfo.DB
  alias OMG.WatcherInfo.Transaction

  import OMG.WatcherInfo.Factory

  require Utxo

  @eth <<0::160>>
  @alice <<27::160>>
  @bob <<28::160>>

  describe "select_inputs/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns {:ok, transctions} when able to select utxos to satisfy payments and fee" do
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)

      utxos_per_token = DB.TxOutput.get_sorted_grouped_utxos(@alice, :desc)

      order = %{
        owner: @alice,
        payments: [
          %{amount: 10, currency: @eth, owner: @bob}
        ],
        fee: %{currency: @eth, amount: 5},
        metadata: nil
      }

      assert {:ok,
              %{
                @eth => [
                  %{amount: 10, currency: @eth},
                  %{amount: 10, currency: @eth}
                ]
              }} = Transaction.select_inputs(utxos_per_token, order)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns error when the funds are not sufficient to satisfy payments and fee" do
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)

      utxos_per_token = DB.TxOutput.get_sorted_grouped_utxos(@alice, :desc)

      order = %{
        owner: @alice,
        payments: [
          %{amount: 30, currency: @eth, owner: @bob}
        ],
        fee: %{currency: @eth, amount: 10},
        metadata: nil
      }

      assert {:error, {:insufficient_funds, [%{missing: 10}]}} = Transaction.select_inputs(utxos_per_token, order)
    end
  end

  describe "create/2" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns {:error, :too_many_outputs} when a number of outputs > maximum" do
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)

      utxos_per_token = DB.TxOutput.get_sorted_grouped_utxos(@alice, :desc)

      order = %{
        owner: @alice,
        payments: [
          %{amount: 9, currency: @eth, owner: @bob},
          %{amount: 9, currency: @eth, owner: <<29::160>>},
          %{amount: 9, currency: @eth, owner: <<30::160>>},
          %{amount: 9, currency: @eth, owner: <<31::160>>},
          %{amount: 9, currency: @eth, owner: <<32::160>>}
        ],
        fee: %{currency: @eth, amount: 9},
        metadata: nil
      }

      assert {:error, :too_many_outputs} == Transaction.create(utxos_per_token, order)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns {:error, :empty_inputs} when a inputs of inputs = 0" do
      order = %{
        owner: @alice,
        payments: [
          %{amount: 45, currency: @eth, owner: @bob}
        ],
        fee: %{currency: @eth, amount: 5},
        metadata: nil
      }

      assert {:error, :empty_transaction} == Transaction.create([], order)
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns {:ok, transactions} when 0 < inputs <= 4 and 0 < outputs <= 4" do
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)

      utxos_per_token = DB.TxOutput.get_sorted_grouped_utxos(@alice, :desc)

      order = %{
        owner: @alice,
        payments: [
          %{amount: 35, currency: @eth, owner: @bob}
        ],
        fee: %{currency: @eth, amount: 5},
        metadata: nil
      }

      assert {:ok,
              [
                %{
                  fee: %{currency: @eth, amount: 5},
                  inputs: [
                    %{amount: 10, currency: @eth},
                    %{amount: 10, currency: @eth},
                    %{amount: 10, currency: @eth},
                    %{amount: 10, currency: @eth}
                  ],
                  outputs: [
                    %{amount: 35, currency: @eth, owner: @bob}
                  ]
                }
              ]} = Transaction.create(utxos_per_token, order)
    end
  end

  describe "include_typed_data/1" do
    test "returns an original error when the param is matched with {:error, _}" do
      assert {:error, :any} == Transaction.include_typed_data({:error, :any})
    end

    @tag fixtures: [:phoenix_ecto_sandbox]
    test "returns transactions with :typed_data" do
      _ = insert(:txoutput, amount: 10, currency: @eth, owner: @alice)

      utxos_per_token = DB.TxOutput.get_sorted_grouped_utxos(@alice, :desc)

      order = %{
        owner: @alice,
        payments: [
          %{amount: 5, currency: @eth, owner: @bob}
        ],
        fee: %{currency: @eth, amount: 5},
        metadata: nil
      }

      {:ok, transactions} = Transaction.create(utxos_per_token, order)

      assert {:ok, %{transactions: transactions}} =
               Transaction.include_typed_data({:ok, %{transactions: transactions, result: :complete}})

      assert Enum.all?(transactions, &Map.has_key?(&1, :typed_data))
    end
  end
end
