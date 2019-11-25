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

  alias OMG.Eth
  alias OMG.State.Transaction
  alias OMG.TestHelper

  use PropCheck
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

  setup_all do
    {:ok, exit_fn} = Support.DevNode.start()

    # taken from the `plasma-contracts` deployment snapshot
    signtest_addr_hex = "0x19925cc645720fbb61f76304ee15501e3197f3a9"
    :ok = Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: signtest_addr_hex})

    on_exit(fn ->
      # reverting to the original values from `omg_eth/config/test.exs`
      :ok =
        Application.put_env(:omg_eth, :contract_addr, %{plasma_framework: "0x0000000000000000000000000000000000000001"})

      exit_fn.()
    end)

    [contract: Eth.Encoding.from_hex(signtest_addr_hex)]
  end

  describe "elixir vs solidity conformance test" do
    # FIXME: simplify all of these tests by not doing signed, just raw should do; remove one `elixir_hash` clause
    # FIXME: also shorten the test by getting the contract in the test title line
    test "signature test empty transaction", context do
      contract = context[:contract]
      tx = TestHelper.create_signed([], [])
      verify(contract, tx)
    end

    test "no inputs test", context do
      contract = context[:contract]
      tx = TestHelper.create_signed([], [{@alice, @eth, 100}])
      verify(contract, tx)
    end

    test "no outputs test", context do
      contract = context[:contract]
      tx = TestHelper.create_signed([{1, 0, 0, @alice}], [])
      verify(contract, tx)
    end

    test "signature test - small tx", context do
      contract = context[:contract]
      tx = TestHelper.create_signed([{1, 0, 0, @alice}], [{@alice, @eth, 100}])
      verify(contract, tx)
    end

    test "signature test - full tx", context do
      contract = context[:contract]

      tx =
        TestHelper.create_signed(
          [{1, 0, 0, @alice}, {1000, 555, 3, @bob}, {2000, 333, 1, @alice}, {15_015, 0, 0, @bob}],
          [{@alice, @eth, 100}, {@alice, @token, 50}, {@bob, @token, 75}, {@bob, @eth, 25}]
        )

      verify(contract, tx)
    end

    test "signature test transaction with metadata", context do
      contract = context[:contract]
      {:ok, <<_::256>> = metadata} = DevCrypto.generate_private_key()

      tx =
        TestHelper.create_signed(
          [{1, 0, 0, @alice}, {1000, 555, 3, @bob}, {2000, 333, 1, @alice}, {15_015, 0, 0, @bob}],
          @eth,
          [{@alice, 100}, {@alice, 50}, {@bob, 75}, {@bob, 25}],
          metadata
        )

      verify(contract, tx)
    end

    test "signature test, transaction with zero output amount", %{contract: contract} do
      tx = Transaction.Payment.new([{1, 0, 0}], [{@alice.addr, @eth, 100}, {<<1::160>>, @zero_address, 0}])
      verify(contract, tx)
    end

    test "signature test, transaction with an explicit zero output", %{contract: contract} do
      tx = Transaction.Payment.new([{1, 0, 0}], [{@alice.addr, @eth, 100}, {@zero_address, @zero_address, 0}])
      verify(contract, tx)
    end

    test "signature test, transaction with an explicit zero input", %{contract: contract} do
      tx = Transaction.Payment.new([{1, 0, 0}, {0, 0, 0}], [{@alice.addr, @eth, 100}])
      verify(contract, tx)
    end

    defp address(), do: union([exactly(<<0::160>>), exactly(<<1::160>>), binary(20)])
    defp hash(), do: union([exactly(<<0::256>>), exactly(<<1::256>>), binary(32)])

    # FIXME: revisit zero inputs, as funny things happen
    defp input_tuple() do
      let [blknum <- pos_integer(), txindex <- non_neg_integer(), oindex <- non_neg_integer()] do
        {blknum, txindex, oindex}
      end
    end

    # FIXME: revisit non_neg_integer amount in a different test case
    # FIXME: revisit the case of negative amounts, funny things happen
    defp output_tuple() do
      let [owner <- address(), currency <- address(), amount <- pos_integer()] do
        {owner, currency, amount}
      end
    end

    # FIXME: move the require
    require Transaction.Payment

    defp valid_inputs_list(),
      do: such_that(l <- list(input_tuple()), when: length(l) <= Transaction.Payment.max_inputs())

    defp valid_outputs_list(),
      do: such_that(l <- list(output_tuple()), when: length(l) <= Transaction.Payment.max_outputs())

    defp payment_tx() do
      let [inputs <- valid_inputs_list(), outputs <- valid_outputs_list(), metadata <- hash()] do
        Transaction.Payment.new(inputs, outputs, metadata)
      end
    end

    @tag :property
    # FIXME: move the property tests elsewhere, decide how to organize their invocation/tags, tidy timouts
    @tag timeout: 240_000
    property "any tx hashes/signhashes the same in all implementations",
             [1000, :verbose, max_size: 100, constraint_tries: 100_000],
             %{contract: contract} do
      forall tx <- payment_tx() do
        # FIXME: expand somewhere with verifying the non-signature-related hash, Transaction.raw_txhash
        verify(contract, tx)
      end
    end

    defp mutated_hash(base_hash) do
      # FIXME: provide more cases
      OMG.Crypto.hash(base_hash)
    end

    defp mutated_inputs(inputs) do
      # FIXME: provide more cases
      if Enum.empty?(inputs), do: valid_inputs_list(), else: tl(inputs)
    end

    defp mutated_outputs(outputs) do
      # FIXME: provide more cases
      if Enum.empty?(outputs), do: valid_outputs_list(), else: tl(outputs)
    end

    defp distinct_payment_txs() do
      proposition_result =
        let [inputs <- valid_inputs_list(), outputs <- valid_outputs_list(), metadata <- hash()] do
          tx1 = Transaction.Payment.new(inputs, outputs, metadata)

          tx2 =
            let [
              inputs2 <- union([inputs, mutated_inputs(inputs)]),
              outputs2 <- union([outputs, mutated_outputs(outputs)]),
              metadata2 <- union([metadata, mutated_hash(metadata)])
            ] do
              Transaction.Payment.new(inputs2, outputs2, metadata2)
            end

          {tx1, tx2}
        end

      such_that({tx1, tx2} <- proposition_result, when: tx1 != tx2)
    end

    @tag :property
    @tag timeout: 240_000
    property "any 2 different txs hash/signhash differently, regardless of implementation",
             [1000, :verbose, max_size: 100, constraint_tries: 100_000],
             %{contract: contract} do
      forall [{tx1, tx2} <- distinct_payment_txs()] do
        # FIXME: expand somewhere with verifying the non-signature-related hash, Transaction.raw_txhash
        verify_distinct(contract, tx1, tx2)
      end
    end

    defp injectable_binary() do
      union([
        binary(),
        <<0::8>>,
        <<1::8>>,
        <<0::16>>,
        <<1::16>>,
        <<0::32>>,
        <<1::32>>,
        <<0::128>>,
        <<1::128>>,
        <<0::256>>,
        <<1::256>>
      ])
    end

    # FIXME: these mutations used could use improving/extending
    defp prepend_binary(base_binary) do
      let(random_binary <- injectable_binary(), do: random_binary <> base_binary)
    end

    # FIXME: these mutations used could use improving/extending
    defp apend_binary(base_binary) do
      let(random_binary <- injectable_binary(), do: base_binary <> random_binary)
    end

    # FIXME: these mutations used could use improving/extending
    defp substring_binary(base_binary) do
      let [index1 <- nat(), index2 <- nat()] do
        base_length = byte_size(base_binary)
        from = min(index1, base_length - 1)
        max_substring_length = max(1, base_length - from)
        substring_length = max(1, min(index2, max_substring_length))

        binary_part(base_binary, from, substring_length)
      end
    end

    # FIXME: these mutations used could use improving/extending
    defp insert_into_binary(base_binary) do
      let [index1 <- nat(), random_binary <- injectable_binary()] do
        base_length = byte_size(base_binary)
        from = min(index1, base_length - 1)
        binary_part(base_binary, 0, from) <> random_binary <> binary_part(base_binary, from, base_length - from)
      end
    end

    defp mutate_binary(base_binary) do
      # FIXME: these mutations used could use improving/extending
      proposition_result =
        union([
          prepend_binary(base_binary),
          apend_binary(base_binary),
          substring_binary(base_binary),
          insert_into_binary(base_binary)
        ])

      such_that(new_binary <- proposition_result, when: new_binary != base_binary)
    end

    defp inject_extra_binary(base_rlp_items) do
      let random_binary <- injectable_binary() do
        base_rlp_items
        |> List.insert_at(0, random_binary)
        |> ExRLP.encode()
      end
    end

    defp rlp_mutate_binary(base_binary) do
      # FIXME: these mutations used could use improving/extending
      base_rlp_items = base_binary |> Transaction.decode!() |> Transaction.Protocol.get_data_for_rlp()

      proposition_result =
        union([
          inject_extra_binary(base_rlp_items)
        ])

      such_that(new_binary <- proposition_result, when: new_binary != base_binary)
    end

    defp tx_binary_with_mutation() do
      let [tx1 <- payment_tx()] do
        tx1_binary = Transaction.raw_txbytes(tx1)
        {tx1_binary, mutate_binary(tx1_binary)}
      end
    end

    defp tx_binary_with_rlp_mutation() do
      let [tx1 <- payment_tx()] do
        tx1_binary = Transaction.raw_txbytes(tx1)
        {tx1_binary, rlp_mutate_binary(tx1_binary)}
      end
    end

    defp decoding_errors_the_same(contract, some_binary) do
      # FIXME: move these two error lists somewhere, after this function has its proper spot
      elixir_decoding_errors = [{:error, :malformed_transaction_rlp}, {:error, :malformed_transaction}]

      solidity_decoding_errors = [
        "Item is not a list",
        "Invalid encoding of transaction",
        "Decoded RLP length for list is invalid",
        "Invalid RLP encoding",
        "Invalid decoded length of RLP item found during counting items in a list"
      ]

      Transaction.decode(some_binary) in elixir_decoding_errors &&
        (solidity_hash(contract, some_binary) |> get_reason_from_call()) in solidity_decoding_errors
    end

    # FIXME: better name
    defp decoding_errors_the_same_rlp_mutated(contract, some_binary) do
      # FIXME: move these two error lists somewhere, after this function has its proper spot
      elixir_decoding_errors = [{:error, :malformed_inputs}, {:error, :malformed_transaction}]

      solidity_decoding_errors = [
        "Item is not a list",
        "Invalid encoding of transaction",
        "Decoded RLP length for list is invalid",
        "Invalid RLP encoding",
        "Invalid decoded length of RLP item found during counting items in a list"
      ]

      Transaction.decode(some_binary) in elixir_decoding_errors &&
        (solidity_hash(contract, some_binary) |> get_reason_from_call()) in solidity_decoding_errors
    end

    @tag :property
    property "any crude-mutated tx binary either fails to decode to a transaction object or is recognized as different",
             [1000, :verbose, max_size: 100, constraint_tries: 100_000],
             %{contract: contract} do
      forall {tx1_binary, tx2_binary} <- tx_binary_with_mutation() do
        decoding_errors_the_same(contract, tx2_binary)
        # FIXME: return to this - this reasoning must be reworked - how do we phrase the condition here?
        # ||
        #           verify_distinct(
        #             contract,
        # FIXME: can we ever hope to fall into this clause?
        #   IO.inspect(Transaction.decode!(tx1_binary)),
        #   IO.inspect(Transaction.decode!(tx2_binary))
        # )
      end
    end

    @tag :property
    # FIXME: remove work tag
    @tag :work
    property "any rlp-mutated tx binary either fails to decode to a transaction object or is recognized as different",
             [1000, :verbose, max_size: 100, constraint_tries: 100_000],
             %{contract: contract} do
      forall {tx1_binary, tx2_binary} <- tx_binary_with_rlp_mutation() do
        decoding_errors_the_same_rlp_mutated(contract, tx2_binary)
        # FIXME: return to this - this reasoning must be reworked - how do we phrase the condition here?
        # ||
        #   verify_distinct(
        #     contract,
        # FIXME: can we ever hope to fall into this clause?
        #   IO.inspect(Transaction.decode!(tx1_binary)),
        #   IO.inspect(Transaction.decode!(tx2_binary))
        # )
      end
    end

    @tag :property
    property "arbitrary binaries never decode",
             [1000, :verbose, max_size: 1000],
             %{contract: contract} do
      forall some_binary <- binary() do
        decoding_errors_the_same(contract, some_binary)
      end
    end

    defp get_reason_from_call({:error, error_body}),
      do: error_body["data"] |> Map.values() |> Enum.at(0) |> Access.get("reason")

    defp verify(contract, tx) do
      assert solidity_hash!(contract, tx) == elixir_hash(tx)
    end
  end

  # FIXME: this might not belong here, technically speaking it could cover the same stuff if put in `plasma_contracts`
  describe "distinct transactions yield distinct sign hashes" do
    test "sanity check - different txs hash differently", %{contract: contract} do
      tx1 = Transaction.Payment.new([{1, 0, 0}], [{@alice.addr, @eth, 100}])
      tx2 = Transaction.Payment.new([{2, 0, 0}], [{@alice.addr, @eth, 100}])
      verify_distinct(contract, tx1, tx2)
    end

    test "explicit zero input alters sign hash", %{contract: contract} do
      tx1 = Transaction.Payment.new([{1, 0, 0}], [{@alice.addr, @eth, 100}])
      tx2 = Transaction.Payment.new([{1, 0, 0}, {0, 0, 0}], [{@alice.addr, @eth, 100}])
      verify_distinct(contract, tx1, tx2)
    end

    test "explicit zero outputs alters sign hash", %{contract: contract} do
      tx1 = Transaction.Payment.new([{1, 0, 0}], [{@alice.addr, @eth, 100}])
      tx2 = Transaction.Payment.new([{1, 0, 0}], [{@alice.addr, @eth, 100}, {@zero_address, @zero_address, 0}])
      verify_distinct(contract, tx1, tx2)
    end

    defp verify_distinct(contract, tx1, tx2) do
      # FIXME: commented now, because they're failing anyway (covered in other tests). Decide how exactly we assert here
      # just sanity checks, the solidity vs elixir testing is in the other section
      # assert solidity_hash!(contract, tx1) == elixir_hash(tx1)
      # assert solidity_hash!(contract, tx2) == elixir_hash(tx2)
      assert solidity_hash!(contract, tx1) != solidity_hash!(contract, tx2)
      assert elixir_hash(tx1) != elixir_hash(tx2)
    end
  end

  defp solidity_hash!(contract, tx) do
    {:ok, solidity_hash} = solidity_hash(contract, tx)
    solidity_hash
  end

  defp solidity_hash(contract, %{} = tx), do: solidity_hash(contract, Transaction.raw_txbytes(tx))

  defp solidity_hash(contract, encoded_tx) when is_binary(encoded_tx),
    do: Eth.call_contract(contract, "hashTx(address,bytes)", [contract, encoded_tx], [{:bytes, 32}])

  defp elixir_hash(%Transaction.Signed{raw_tx: tx}), do: OMG.TypedDataHash.hash_struct(tx)
  defp elixir_hash(tx), do: OMG.TypedDataHash.hash_struct(tx)
end
