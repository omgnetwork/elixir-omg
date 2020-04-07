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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeClaimerAddressTest do
  use ExUnit.Case, async: false
  alias OMG.ChildChain.ReleaseTasks.SetFeeClaimerAddress

  @app :omg
  @config_key :fee_claimer_address
  @env_var_name "FEE_CLAIMER_ADDRESS"
  @old_value Application.get_env(@app, @config_key)
  @default_fee_claimer_address_hex "0xDEAD000000000000000000000000000000000000"
  @default_fee_claimer_address Base.decode16!("DEAD000000000000000000000000000000000000")

  setup do
    :ok = System.put_env(@env_var_name, @default_fee_claimer_address_hex)
    :ok = Application.delete_env(@app, @config_key)

    on_exit(fn ->
      :ok = Application.put_env(@app, @config_key, @old_value)
      :ok = System.delete_env(@env_var_name)
    end)
  end

  test "env var has always to be set or task will fail" do
    :ok = System.delete_env(@env_var_name)

    assert catch_exit(SetFeeClaimerAddress.init([])) =~ "needs to be specified"
  end

  test "when configured properly correct address is set" do
    :ok = SetFeeClaimerAddress.init([])

    assert @default_fee_claimer_address == Application.get_env(@app, @config_key)
  end

  test "chars casing or leading 0x do not affect the value" do
    :ok = System.put_env(@env_var_name, "deAD000000000000000000000000000000000000")
    :ok = SetFeeClaimerAddress.init([])

    assert @default_fee_claimer_address == Application.get_env(@app, @config_key)
  end

  test "zero address is not accepted value" do
    :ok = System.put_env(@env_var_name, "0000000000000000000000000000000000000000")

    assert catch_exit(SetFeeClaimerAddress.init([])) =~ "cannot be zero-bytes"
  end

  test "address has to have a proper length of 20-bytes" do
    :ok = System.put_env(@env_var_name, "0xabcdef")

    assert catch_exit(SetFeeClaimerAddress.init([])) =~ "has to be 20-bytes long"
  end

  test "address has to be HEX encoded string" do
    :ok = System.put_env(@env_var_name, "OMG FTW!")

    assert catch_exit(SetFeeClaimerAddress.init([])) =~ "has to be HEX-encoded"
  end
end
