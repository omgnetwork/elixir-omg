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

defmodule OMG.ChildChainRPC.Web.Controller.FeeTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OMG.ChildChainRPC.Web.TestHelper

  @payment_tx_type OMG.WireFormatTypes.tx_type_for(:tx_payment_v1)

  setup_all do
    fee_specs = %{
      @payment_tx_type => %{
        Base.decode16!("0000000000000000000000000000000000000000") => %{
          amount: 1,
          subunit_to_unit: 1_000_000_000_000_000_000,
          pegged_amount: 1,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 100,
          updated_at: DateTime.from_unix!(1_546_336_800)
        },
        Base.decode16!("0000000000000000000000000000000000000001") => %{
          amount: 2,
          subunit_to_unit: 1_000_000_000_000_000_000,
          pegged_amount: 1,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 100,
          updated_at: DateTime.from_unix!(1_546_336_800)
        }
      },
      2 => %{
        Base.decode16!("0000000000000000000000000000000000000000") => %{
          amount: 2,
          subunit_to_unit: 1_000_000_000_000_000_000,
          pegged_amount: 1,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 100,
          updated_at: DateTime.from_unix!(1_546_336_800)
        }
      }
    }

    _ = if :undefined == :ets.info(:fees_bucket), do: :ets.new(:fees_bucket, [:set, :public, :named_table])
    true = :ets.insert(:fees_bucket, [{:fees, fee_specs}])
    %{}
  end

  describe "fees_all/2" do
    @tag fixtures: [:phoenix_sandbox]
    test "fees.all endpoint filters the result when given currencies" do
      assert %{
               "success" => true,
               "data" => %{
                 "1" => [
                   %{
                     "amount" => 1,
                     "currency" => "0x0000000000000000000000000000000000000000",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   }
                 ],
                 "2" => [
                   %{
                     "amount" => 2,
                     "currency" => "0x0000000000000000000000000000000000000000",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   }
                 ]
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{currencies: ["0x0000000000000000000000000000000000000000"]})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all endpoint does not filter when given empty currencies" do
      assert %{
               "success" => true,
               "data" => %{
                 "1" => [
                   %{
                     "amount" => 1,
                     "currency" => "0x0000000000000000000000000000000000000000",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   },
                   %{
                     "amount" => 1,
                     "currency" => "0x0000000000000000000000000000000000000001",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   }
                 ],
                 "2" => [
                   %{
                     "amount" => 2,
                     "currency" => "0x0000000000000000000000000000000000000000",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   }
                 ]
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{currencies: []})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all endpoint does not filter without an empty body" do
      assert %{
               "success" => true,
               "data" => %{
                 "1" => [
                   %{
                     "amount" => 1,
                     "currency" => "0x0000000000000000000000000000000000000000",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   },
                   %{
                     "amount" => 1,
                     "currency" => "0x0000000000000000000000000000000000000001",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   }
                 ],
                 "2" => [
                   %{
                     "amount" => 2,
                     "currency" => "0x0000000000000000000000000000000000000000",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   }
                 ]
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all returns an error when given unsupported currency" do
      assert %{
               "success" => false,
               "data" => %{
                 "object" => "error",
                 "code" => "fee:currency_fee_not_supported",
                 "description" => "One or more of the given currencies are not supported as a fee-token."
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{currencies: ["0x0000000000000000000000000000000000000005"]})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all endpoint rejects request with non list currencies" do
      assert %{
               "success" => false,
               "data" => %{
                 "object" => "error",
                 "code" => "operation:bad_request",
                 "messages" => %{
                   "validation_error" => %{
                     "parameter" => "currencies",
                     "validator" => ":list"
                   }
                 }
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{currencies: "0x0000000000000000000000000000000000000000"})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all endpoint rejects request with non hex currencies" do
      assert %{
               "success" => false,
               "data" => %{
                 "object" => "error",
                 "code" => "operation:bad_request",
                 "messages" => %{
                   "validation_error" => %{
                     "parameter" => "currencies.currency",
                     "validator" => ":hex"
                   }
                 }
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{currencies: ["invalid"]})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all endpoint filters the result when given tx_types" do
      assert %{
               "success" => true,
               "data" => %{
                 "1" => [
                   %{
                     "amount" => 1,
                     "currency" => "0x0000000000000000000000000000000000000000",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   },
                   %{
                     "amount" => 1,
                     "currency" => "0x0000000000000000000000000000000000000001",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   }
                 ]
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{tx_types: [@payment_tx_type]})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all endpoint does not filter when given empty tx_types" do
      assert %{
               "success" => true,
               "data" => %{
                 "1" => [
                   %{
                     "amount" => 1,
                     "currency" => "0x0000000000000000000000000000000000000000",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   },
                   %{
                     "amount" => 1,
                     "currency" => "0x0000000000000000000000000000000000000001",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   }
                 ],
                 "2" => [
                   %{
                     "amount" => 2,
                     "currency" => "0x0000000000000000000000000000000000000000",
                     "subunit_to_unit" => 1_000_000_000_000_000_000,
                     "pegged_amount" => 1,
                     "pegged_currency" => "USD",
                     "pegged_subunit_to_unit" => 100,
                     "updated_at" => "2019-01-01T10:00:00Z"
                   }
                 ]
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{tx_types: []})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all returns an error when given unsupported tx_types" do
      assert %{
               "success" => false,
               "data" => %{
                 "object" => "error",
                 "code" => "fee:tx_type_not_supported",
                 "description" => "One or more of the given transaction types are not supported."
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{tx_types: [99_999]})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all endpoint rejects request with non list tx_types" do
      assert %{
               "success" => false,
               "data" => %{
                 "object" => "error",
                 "code" => "operation:bad_request",
                 "messages" => %{
                   "validation_error" => %{
                     "parameter" => "tx_types",
                     "validator" => ":list"
                   }
                 }
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{tx_types: 1})
    end

    @tag fixtures: [:phoenix_sandbox]
    test "fees.all endpoint rejects request with negative integer" do
      assert %{
               "success" => false,
               "data" => %{
                 "object" => "error",
                 "code" => "operation:bad_request",
                 "messages" => %{
                   "validation_error" => %{
                     "parameter" => "tx_types.tx_type",
                     "validator" => "{:greater, -1}"
                   }
                 }
               }
             } = TestHelper.rpc_call(:post, "/fees.all", %{tx_types: [-5]})
    end
  end
end
