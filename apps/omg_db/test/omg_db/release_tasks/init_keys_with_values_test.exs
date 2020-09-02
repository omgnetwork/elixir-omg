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

defmodule OMG.DB.ReleaseTasks.InitKeysWithValuesTest do
  use ExUnit.Case, async: false
  alias OMG.DB.ReleaseTasks.InitKeysWithValues

  setup_all do
    _ = :ets.new(:test_table, [:public, :named_table])
    []
  end

  test ":last_ife_exit_deleted_eth_height is set if it wasn't set previously", %{test: test_name} do
    defmodule test_name do
      def get_single_value(:last_ife_exit_deleted_eth_height), do: :not_found

      def multi_update([{:put, :last_ife_exit_deleted_eth_height, init_val}]) do
        _ = :ets.insert(:test_table, {Atom.to_string(:last_ife_exit_deleted_eth_height), init_val})
        :ok
      end
    end

    assert [] == InitKeysWithValues.load([], db_module: test_name)

    ets_key = Atom.to_string(:last_ife_exit_deleted_eth_height)

    assert [{ets_key, 0}] == :ets.lookup(:test_table, ets_key)
  end

  test "value under :last_ife_exit_deleted_eth_height is not changed if it wasn't set previously", %{test: test_name} do
    defmodule test_name do
      def get_single_value(:last_ife_exit_deleted_eth_height), do: {:ok, 1}

      def multi_update([{:put, _key, _init_val}]), do: flunk("Must not be called")
    end

    assert [] == InitKeysWithValues.load([], db_module: test_name)
  end
end
