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

defmodule OMG.State.UtxoSetTest do
  @moduledoc """
  Low-level unit test of `OMG.State.UtxoSet`
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.InputPointer
  alias OMG.State.Transaction
  alias OMG.State.UtxoSet
  alias OMG.Utxo

  import OMG.TestHelper, only: [generate_entity: 0, create_recovered: 2]

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  setup do
    [alice, bob] = 1..2 |> Enum.map(fn _ -> generate_entity() end)

    transaction = create_recovered([{1, 0, 0, alice}, {2, 0, 0, bob}], [{bob, @eth, 1}, {bob, @eth, 2}])
    inputs = Transaction.get_inputs(transaction)
    outputs = Transaction.get_outputs(transaction)

    db_query_result =
      inputs
      |> Enum.zip(outputs)
      |> Enum.map(fn {input, output} -> {input, %Utxo{output: output, creating_txhash: <<1>>}} end)
      |> Enum.map(fn {input, utxo} -> {InputPointer.Protocol.to_db_key(input), Utxo.to_db_value(utxo)} end)

    utxo_set = UtxoSet.init(db_query_result)

    {:ok,
     %{alice: alice, bob: bob, inputs: inputs, outputs: outputs, db_query_result: db_query_result, utxo_set: utxo_set}}
  end

  describe "init/1" do
    test "can initialize empty", %{inputs: inputs} do
      assert {:error, :utxo_not_found} =
               []
               |> UtxoSet.init()
               |> UtxoSet.get_by_inputs(inputs)
    end

    test "can initialize with db query result", %{inputs: inputs, outputs: outputs, db_query_result: db_query_result} do
      assert {:ok, ^outputs} =
               db_query_result
               |> UtxoSet.init()
               |> UtxoSet.get_by_inputs(inputs)
    end
  end

  describe "merge_with_query_result/2" do
    test "overwrites existing entries", %{alice: alice, db_query_result: db_query_result, utxo_set: utxo_set} do
      new_output =
        create_recovered([], [{alice, @eth, 100}])
        |> Transaction.get_outputs()
        |> Enum.map(&%Utxo{output: &1, creating_txhash: <<1>>})
        |> Kernel.hd()

      db_output = Utxo.to_db_value(new_output)
      {db_key, _} = hd(db_query_result)
      key = InputPointer.from_db_key(db_key)

      # replace utxo with existing key
      expected_utxo_set = Map.put(utxo_set, key, new_output)

      assert expected_utxo_set == UtxoSet.merge_with_query_result(utxo_set, [{db_key, db_output}])
    end

    test "merge into empty map", %{db_query_result: db_query_result, utxo_set: utxo_set} do
      assert utxo_set == UtxoSet.merge_with_query_result(%{}, db_query_result)
    end

    test "merge with empty query results", %{db_query_result: db_query_result, utxo_set: utxo_set} do
      assert utxo_set == UtxoSet.merge_with_query_result(utxo_set, [])
    end
  end

  describe "get_by_inputs/2" do
    test "will get all by inputs in input order", %{inputs: inputs, utxo_set: utxo_set} do
      {:ok, result1} = UtxoSet.get_by_inputs(utxo_set, inputs)
      assert {:ok, Enum.reverse(result1)} == UtxoSet.get_by_inputs(utxo_set, Enum.reverse(inputs))
      assert {:ok, result1 ++ result1} == UtxoSet.get_by_inputs(utxo_set, inputs ++ inputs)
    end

    test "will get for empty inputs", %{utxo_set: utxo_set} do
      assert {:ok, []} = UtxoSet.get_by_inputs(utxo_set, [])
    end

    test "will get for subset of inputs", %{inputs: [input | _], outputs: [output | _], utxo_set: utxo_set} do
      assert {:ok, [^output]} = UtxoSet.get_by_inputs(utxo_set, [input])
    end
  end

  describe "apply_effects/3" do
    test "will apply effects of spends", %{inputs: [input1, input2 | _], outputs: [output1 | _], utxo_set: utxo_set} do
      assert {:ok, [^output1]} =
               utxo_set
               |> UtxoSet.apply_effects([input2], %{})
               |> UtxoSet.get_by_inputs([input1])

      assert {:error, :utxo_not_found} =
               utxo_set
               |> UtxoSet.apply_effects([input2], %{})
               |> UtxoSet.get_by_inputs([input2])
    end

    test "will apply effects of new utxos being created", %{inputs: [input | _], outputs: [output | _]} do
      utxo_map = %{input => %Utxo{output: output, creating_txhash: <<1>>}}

      assert {:ok, [^output]} =
               [] |> UtxoSet.init() |> UtxoSet.apply_effects([], utxo_map) |> UtxoSet.get_by_inputs([input])
    end

    test "will create first, spend second", %{inputs: [input | _], outputs: [output | _]} do
      # this would not happen now, since `apply_effects/3` is called per tx, which cannot spend it's own input
      # nevertheless, let's make sure this is catered for on this level too
      utxo_map = %{input => %Utxo{output: output, creating_txhash: <<1>>}}

      assert {:error, :utxo_not_found} =
               [] |> UtxoSet.init() |> UtxoSet.apply_effects([input], utxo_map) |> UtxoSet.get_by_inputs([input])
    end
  end

  describe "db_updates/2" do
    test "will write to db, creating first, spending second", %{inputs: [input | _], outputs: [output | _]} do
      # this would not happen now, since `apply_effects/3` is called per tx, which cannot spend it's own input
      # nevertheless, let's make sure this is catered for on this level too
      utxo_map = %{input => %Utxo{output: output, creating_txhash: <<1>>}}

      assert [{:put, :utxo, {key, _}}, {:delete, :utxo, key}] = UtxoSet.db_updates([input], utxo_map)
    end
  end

  describe "exists?/2" do
    test "false if input absent", %{inputs: [input | _]} do
      refute [] |> UtxoSet.init() |> UtxoSet.exists?(input)
    end

    test "true if present", %{inputs: [input | _], utxo_set: utxo_set} do
      assert UtxoSet.exists?(utxo_set, input)
    end
  end

  describe "find_matching_utxo/3" do
    test "will find pair if matches", %{inputs: [input | _], outputs: [output | _]} do
      utxo_map = %{input => %Utxo{output: output, creating_txhash: <<1>>}}

      assert hd(Map.to_list(utxo_map)) ==
               [] |> UtxoSet.init() |> UtxoSet.apply_effects([], utxo_map) |> UtxoSet.find_matching_utxo(<<1>>, 0)
    end

    test "won't find if none matches", %{inputs: [input | _], outputs: [output | _]} do
      utxo_map = %{input => %Utxo{output: output, creating_txhash: <<1>>}}
      refute [] |> UtxoSet.init() |> UtxoSet.apply_effects([], utxo_map) |> UtxoSet.find_matching_utxo(<<1>>, 1)
      refute [] |> UtxoSet.init() |> UtxoSet.find_matching_utxo(<<1>>, 0)
    end
  end

  describe "filter_owned_by/2" do
    test "will find Bob's utxos", %{bob: bob, utxo_set: utxo_set} do
      assert [_, _] = UtxoSet.filter_owned_by(utxo_set, bob.addr) |> Enum.to_list()
    end

    test "will NOT find Alice's utxos, b/c she doesn't have any", %{alice: alice, utxo_set: utxo_set} do
      assert [] = UtxoSet.filter_owned_by(utxo_set, alice.addr) |> Enum.to_list()
    end
  end

  describe "zip_with_positions/1" do
    test "will zip all utxos with their positions", %{utxo_set: utxo_set} do
      # for now a trivial test case. When input pointers other than `utxo_pos` are used this becomes relevant
      assert [{_, Utxo.position(1, 0, 0)}, {_, Utxo.position(2, 0, 0)}] =
               UtxoSet.zip_with_positions(utxo_set) |> Enum.to_list()
    end
  end
end
