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

defmodule OMG.ChildChain.FileAdapterTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OMG.ChildChain.Fees.FileAdapter
  alias OMG.Eth
  alias OMG.TestHelper

  doctest OMG.ChildChain.Fees.FileAdapter

  @eth Eth.zero_address()
  @eth_hex Eth.Encoding.to_hex(@eth)
  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)
  @fees %{
    @payment_tx_type => %{
      @eth_hex => %{
        amount: 1,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      }
    }
  }

  @stored_fees_empty %{}

  describe "get_fee_specs/1" do
    test "returns the fee specs if recorded_file_updated_at is older than
          actual_file_updated_at" do
      recorded_file_updated_at = :os.system_time(:second) - 10

      {:ok, file_path} = TestHelper.write_fee_file(@fees)
      {:ok, %File.Stat{mtime: mtime}} = File.stat(file_path, time: :posix)
      opts = [specs_file_path: file_path]

      assert FileAdapter.get_fee_specs(opts, @stored_fees_empty, recorded_file_updated_at) == {
               :ok,
               %{@payment_tx_type => %{@eth => @fees[1][@eth_hex]}},
               mtime
             }

      File.rm(file_path)
    end

    test "returns :ok (unchanged) if file_updated_at is more recent
          than file last change timestamp" do
      {:ok, file_path} = TestHelper.write_fee_file(@fees)
      opts = [specs_file_path: file_path]
      recorded_file_updated_at = :os.system_time(:second) + 10

      assert FileAdapter.get_fee_specs(opts, @stored_fees_empty, recorded_file_updated_at) == :ok
      File.rm(file_path)
    end

    test "returns an error if the file is not found" do
      opts = [specs_file_path: "fake_path/fake_fee_file.json"]
      assert FileAdapter.get_fee_specs(opts, @stored_fees_empty, 1) == {:error, :enoent}
    end
  end
end
