defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API.Block
  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Transaction.{Recovered, Signed}
  alias OmiseGO.API.Utxo
  require Utxo
  alias OmiseGOWatcher.TransactionDB

  @eth Crypto.zero_address()

  @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
  test "insert and retrive transaction", %{alice: alice, bob: bob} do
    tester_f = fn {txblknum, txindex, recovered_tx} ->
      [{:ok, %TransactionDB{txid: id}}] = TransactionDB.update_with(%{transactions: [recovered_tx], number: txblknum})
      expected_transaction = create_expected_transaction(id, recovered_tx, txblknum, txindex)
      assert expected_transaction == delete_meta(TransactionDB.get(id))
    end

    [
      {0, 0, OmiseGO.API.TestHelper.create_recovered([], @eth, [])},
      {0, 0, OmiseGO.API.TestHelper.create_recovered([{2, 3, 1, bob}], @eth, [{alice, 200}])},
      {0, 0, OmiseGO.API.TestHelper.create_recovered([{2, 3, 1, bob}, {2, 3, 1, alice}], @eth, [{alice, 200}])},
      {0, 0, OmiseGO.API.TestHelper.create_recovered([{2, 3, 1, bob}], @eth, [{alice, 200}, {bob, 200}])},
      {1000, 0, OmiseGO.API.TestHelper.create_recovered([{2, 3, 2, bob}, {2, 3, 1, alice}], @eth, [{alice, 200}])}
    ]
    |> Enum.map(tester_f)
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
  test "insert and retrive block of transactions ", %{alice: alice, bob: bob} do
    txblknum = 0
    recovered_tx1 = OmiseGO.API.TestHelper.create_recovered([{2, 3, 1, bob}], @eth, [{alice, 200}])
    recovered_tx2 = OmiseGO.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [])

    [{:ok, %TransactionDB{txid: txid_1}}, {:ok, %TransactionDB{txid: txid_2}}] =
      TransactionDB.update_with(%Block{
        transactions: [
          recovered_tx1,
          recovered_tx2
        ],
        number: txblknum
      })

    assert create_expected_transaction(txid_1, recovered_tx1, txblknum, 0) == delete_meta(TransactionDB.get(txid_1))
    assert create_expected_transaction(txid_2, recovered_tx2, txblknum, 1) == delete_meta(TransactionDB.get(txid_2))
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
  test "gets all transactions from a block", %{alice: alice, bob: bob} do
    assert [] == TransactionDB.find_by_txblknum(1)

    alice_spend_recovered = OmiseGO.API.TestHelper.create_recovered([], @eth, [{alice, 100}])
    bob_spend_recovered = OmiseGO.API.TestHelper.create_recovered([], @eth, [{bob, 200}])

    [{:ok, %TransactionDB{txid: txid_alice}}, {:ok, %TransactionDB{txid: txid_bob}}] =
      TransactionDB.update_with(%Block{
        transactions: [alice_spend_recovered, bob_spend_recovered],
        number: 1
      })

    assert [
             create_expected_transaction(txid_alice, alice_spend_recovered, 1, 0),
             create_expected_transaction(txid_bob, bob_spend_recovered, 1, 1)
           ] == 1 |> TransactionDB.find_by_txblknum() |> Enum.map(&delete_meta/1)
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
  test "gets transaction that spends utxo", %{alice: alice, bob: bob} do
    utxo1 = Utxo.position(1, 0, 0)
    utxo2 = Utxo.position(2, 0, 0)
    :utxo_not_spent = TransactionDB.get_transaction_challenging_utxo(utxo1)
    :utxo_not_spent = TransactionDB.get_transaction_challenging_utxo(utxo2)

    alice_spend_recovered = OmiseGO.API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [])

    [{:ok, %TransactionDB{txid: txid_alice}}] =
      TransactionDB.update_with(%Block{
        transactions: [alice_spend_recovered],
        number: 1
      })

    assert create_expected_transaction(txid_alice, alice_spend_recovered, 1, 0) ==
             delete_meta(TransactionDB.get_transaction_challenging_utxo(utxo1))

    :utxo_not_spent = TransactionDB.get_transaction_challenging_utxo(utxo2)

    bob_spend_recovered = OmiseGO.API.TestHelper.create_recovered([{2, 0, 0, bob}], @eth, [])

    [{:ok, %TransactionDB{txid: txid_bob}}] =
      TransactionDB.update_with(%Block{
        transactions: [bob_spend_recovered],
        number: 2
      })

    assert create_expected_transaction(txid_bob, bob_spend_recovered, 2, 0) ==
             delete_meta(TransactionDB.get_transaction_challenging_utxo(utxo2))
  end

  defp create_expected_transaction(
         txid,
         %Recovered{
           signed_tx: %Signed{raw_tx: transaction, sig1: sig1, sig2: sig2},
           spender1: spender1,
           spender2: spender2
         },
         txblknum,
         txindex
       ) do
    %TransactionDB{
      txblknum: txblknum,
      txindex: txindex,
      txid: txid,
      sig1: sig1,
      sig2: sig2,
      spender1: spender1,
      spender2: spender2
    }
    |> Map.merge(Map.from_struct(transaction))
    |> delete_meta
  end

  defp delete_meta({:ok, %TransactionDB{} = transaction}) do
    Map.delete(transaction, :__meta__)
  end

  defp delete_meta(%TransactionDB{} = transaction) do
    Map.delete(transaction, :__meta__)
  end
end
