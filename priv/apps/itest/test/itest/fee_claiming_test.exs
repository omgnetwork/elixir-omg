defmodule FeeClaimingTests do
  use Cabbage.Feature, async: false, file: "fee_claiming.feature"

  require Logger

  alias Itest.Account
  alias Itest.Client
  alias Itest.Transactions.Currency

  @fee_claimer_address "0x3b9f4c1dd26e0be593373b1d36cee2008cbeb837"
  @expected_fee_rule %{"amount" => 1, "currency" => "0x0000000000000000000000000000000000000000"}

  setup do
    [{alice_address, alice_pkey}, {bob_address, bob_pkey}] = Account.take_accounts(2)

    initial_balance =
      @fee_claimer_address
      |> Client.get_balance()
      |> fix_balance_response()

    assert_equal(@expected_fee_rule["currency"], initial_balance["currency"], "fee expected currency")

    %{
      "Alice" => %{
        address: alice_address,
        pkey: alice_pkey
      },
      "Bob" => %{
        address: bob_address,
        pkey: bob_pkey
      },
      "FeeClaimer" => %{address: @fee_claimer_address},
      fees_initial_balance: initial_balance,
      gas: 0
    }
  end

  defwhen ~r/^"(?<entity>[^"]+)" deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{entity: entity, amount: amount},
          state do
    entity_address = get_entity(state, entity).address

    {:ok, receipt_hash} =
      amount
      |> Currency.to_wei()
      |> Client.deposit(entity_address, Itest.Account.vault(Currency.ether()))

    gas_used = Client.get_gas_used(receipt_hash)

    {_, new_state} =
      Map.get_and_update!(state, :gas, fn current_gas ->
        {current_gas, current_gas + gas_used}
      end)

    {:ok, new_state}
  end

  defwhen ~r/^"(?<sender>[^"]+)" sends "(?<receiver>[^"]+)" "(?<amount>[^"]+)" ETH on the child chain$/,
          %{sender: sender, receiver: receiver, amount: amount},
          state do
    sender = get_entity(state, sender)
    receiver = get_entity(state, receiver)

    {:ok, [sign_hash, typed_data, _txbytes]} =
      Client.create_transaction(
        Currency.to_wei(amount),
        sender.address,
        receiver.address
      )

    _ = Client.submit_transaction(typed_data, sign_hash, [sender.pkey])

    {:ok, state}
  end

  defthen ~r/^"(?<entity>[^"]+)" should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{entity: entity, amount: amount},
          state do
    entity_address = get_entity(state, entity).address
    expecting_amount = Currency.to_wei(amount)

    balance =
      entity_address
      |> Client.get_balance(expecting_amount)
      |> fix_balance_response()

    balance = balance["amount"]
    assert_equal(expecting_amount, balance, "For #{entity}")
    {:ok, state}
  end

  defthen ~r/^Operator has claimed the fees$/, _, %{fees_initial_balance: initial_balance} do
    actual_balance =
      @fee_claimer_address
      |> Client.get_balance()
      |> fix_balance_response()

    assert_equal(
      initial_balance["amount"] + @expected_fee_rule["amount"],
      actual_balance["amount"],
      "amount of fees claimed"
    )

    assert_equal(@expected_fee_rule["currency"], actual_balance["currency"], "currency of fees claimed")
  end

  defp assert_equal(left, right, message) do
    assert(left == right, "Expected #{left}, but have #{right}." <> message)
  end

  defp get_entity(state, entity) do
    state[entity]
  end

  # TODO: Remove when fixed. See issue: omisego/elixir-omg/issues/1293
  defp fix_balance_response(response) when is_map(response), do: response
  defp fix_balance_response([response]), do: fix_balance_response(response)
  defp fix_balance_response([]), do: %{"amount" => 0}
end
