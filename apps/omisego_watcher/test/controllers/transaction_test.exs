defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGOWatcher.TransactionDB
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}
  alias OmiseGO.API.{Block}

  @moduletag :watcher_tests

  @signed_tx %Signed{
    raw_tx: %Transaction{
      blknum1: 0,
      txindex1: 0,
      oindex1: 0,
      blknum2: 0,
      txindex2: 0,
      oindex2: 0,
      newowner1: "",
      amount1: 0,
      newowner2: "",
      amount2: 0,
      fee: 0
    },
    sig1: <<>>,
    sig2: <<>>
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmiseGOWatcher.Repo)
  end

  test "insert and retrieve transaction" do
    txblknum = 0
    txindex = 0
    id = Signed.signed_hash(@signed_tx)

    {:ok, %TransactionDB{txid: id}} = TransactionDB.insert(id, @signed_tx, txblknum, txindex)

    expected_transaction = create_expected_transaction(id, @signed_tx, txblknum, txindex)

    assert expected_transaction == delete_meta(TransactionDB.get(id))
  end

  test "insert and retrieve block of transactions" do
    txblknum = 0

    signed_tx_1 = @signed_tx
    signed_tx_2 = put_in(@signed_tx.raw_tx.blknum1, 1)

    [{:ok, %TransactionDB{txid: txid_1}}, {:ok, %TransactionDB{txid: txid_2}}] =
      TransactionDB.insert(
        %Block{
          transactions: [
            signed_tx_1,
            signed_tx_2
          ]
        },
        txblknum
      )

    expected_transaction_1 = create_expected_transaction(txid_1, signed_tx_1, txblknum, 0)
    expected_transaction_2 = create_expected_transaction(txid_2, signed_tx_2, txblknum, 1)

    assert expected_transaction_1 == delete_meta(TransactionDB.get(txid_1))
    assert expected_transaction_2 == delete_meta(TransactionDB.get(txid_2))
  end

  describe "get transaction spending utxo" do

    test "returns transaction that spends utxo" do
      id = Signed.signed_hash(@signed_tx)
      {:ok, %TransactionDB{txid: ^id}} = TransactionDB.insert(id, @signed_tx, 1, 1)

      utxo = %{blknum: @signed_tx.blknum1, txindex: @signed_tx.txindex1, oindex: @signed_tx.oindex1}
      {:ok, %TransactionDB{txid: ^id}} = TransactionDB.get_transaction_spending_utxo(utxo)
    end

    test "signals when spending transaction does not exist" do
    end

  end

  defp create_expected_transaction(txid, signed_tx, txblknum, txindex) do
    %TransactionDB{
      txblknum: txblknum,
      txindex: txindex,
      txid: txid
    }
    |> Map.merge(Map.from_struct(signed_tx.raw_tx))
    |> delete_meta
  end

  defp delete_meta(%TransactionDB{} = transaction) do
    Map.delete(transaction, :__meta__)
  end
end
