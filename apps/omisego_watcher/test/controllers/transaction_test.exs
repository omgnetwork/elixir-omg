defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}
  alias OmiseGOWatcher.TransactionDB

  @zero_address <<0::size(160)>>

  @signed_tx %Signed{
    raw_tx: %Transaction{
      blknum1: 0,
      txindex1: 0,
      oindex1: 0,
      blknum2: 0,
      txindex2: 0,
      oindex2: 0,
      cur12: @zero_address,
      newowner1: @zero_address,
      amount1: 1,
      newowner2: @zero_address,
      amount2: 0
    },
    sig1: <<1, 8, 10, 12>>,
    sig2: <<14, 16, 18, 20>>
  }

  @tag fixtures: [:watcher_sandbox]
  test "insert and retrive transaction" do
    txblknum = 0
    txindex = 0
    id = Signed.signed_hash(@signed_tx)

    {:ok, %TransactionDB{txid: id}} = TransactionDB.insert(id, @signed_tx, txblknum, txindex)

    expected_transaction = create_expected_transaction(id, @signed_tx, txblknum, txindex)

    assert expected_transaction == delete_meta(TransactionDB.get(id))
  end

  @tag fixtures: [:watcher_sandbox]
  test "insert and retrive block of transactions " do
    txblknum = 0

    signed_tx_1 = @signed_tx
    signed_tx_2 = put_in(@signed_tx.raw_tx.blknum1, 1)

    [{:ok, %TransactionDB{txid: txid_1}}, {:ok, %TransactionDB{txid: txid_2}}] =
      TransactionDB.insert(%Block{
        transactions: [
          signed_tx_1,
          signed_tx_2
        ],
        number: txblknum
      })

    expected_transaction_1 = create_expected_transaction(txid_1, signed_tx_1, txblknum, 0)
    expected_transaction_2 = create_expected_transaction(txid_2, signed_tx_2, txblknum, 1)

    assert expected_transaction_1 == delete_meta(TransactionDB.get(txid_1))
    assert expected_transaction_2 == delete_meta(TransactionDB.get(txid_2))
  end

  test "gets all transactions from a block" do
    assert [] == TransactionDB.get_transactions_from_block(1)

    tx1 = insert_tx(1, 0)
    tx2 = insert_tx(1, 1)
    insert_tx(2, 0)

    assert [tx1, tx2] == TransactionDB.get_transactions_from_block(1)
  end

  defp insert_tx(blknum, txindex) do
    {signed_tx, id} = create_tx_with_id(blknum, txindex)
    {:ok, tx} = TransactionDB.insert(id, signed_tx, blknum, txindex)
    tx
  end

  defp create_tx_with_id(blknum, txindex) do
    tx = %{@signed_tx.raw_tx | blknum1: blknum, txindex1: txindex}
    signed_tx = %Signed{raw_tx: tx, sig1: <<>>, sig2: <<>>}
    id = Signed.signed_hash(signed_tx)
    {signed_tx, id}
  end

  test "gets transaction that spends utxo" do
    utxo1 = %{blknum: 1, txindex: 0, oindex: 0}
    utxo2 = %{blknum: 2, txindex: 0, oindex: 0}
    :utxo_not_spent = TransactionDB.get_transaction_spending_utxo(utxo1)
    :utxo_not_spent = TransactionDB.get_transaction_spending_utxo(utxo2)

    assert_transaction_spends_utxo(utxo1, 0)
    :utxo_not_spent = TransactionDB.get_transaction_spending_utxo(utxo2)
    assert_transaction_spends_utxo(utxo2, 1)
  end

  defp assert_transaction_spends_utxo(utxo, txindex) do
    {signed_tx, id} = create_tx_with_id(utxo.blknum, 0)
    {:ok, _} = TransactionDB.insert(id, signed_tx, 2, txindex)
    expected_tx = create_expected_transaction(id, signed_tx, 2, txindex)

    {:ok, actual_tx} = TransactionDB.get_transaction_spending_utxo(utxo)
    assert expected_tx == delete_meta(actual_tx)
  end

  defp create_expected_transaction(txid, signed_tx, txblknum, txindex) do
    %TransactionDB{
      txblknum: txblknum,
      txindex: txindex,
      txid: txid,
      sig1: signed_tx.sig1,
      sig2: signed_tx.sig2
    }
    |> Map.merge(Map.from_struct(signed_tx.raw_tx))
    |> delete_meta
  end

  defp delete_meta(%TransactionDB{} = transaction) do
    Map.delete(transaction, :__meta__)
  end
end
