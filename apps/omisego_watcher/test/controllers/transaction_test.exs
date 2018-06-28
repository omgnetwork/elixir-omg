defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGO.API.Block
  alias OmiseGOWatcher.TransactionDB

  @moduletag :integration

  @tag fixtures: [:watcher_sandbox]
  test "insert and retrive transaction" do
    txblknum = 0
    txindex = 0
    recovered = OmiseGO.API.TestHelper.create_recovered([], [])
    {:ok, %TransactionDB{txid: id}} = TransactionDB.insert(recovered, txblknum, txindex)
    expected_transaction = create_expected_transaction(id, recovered, txblknum, txindex)
    assert expected_transaction == delete_meta(TransactionDB.get(id))
  end

  @tag fixtures: [:watcher_sandbox]
  test "insert and retrive block of transactions " do
    txblknum = 0
    recovered1 = OmiseGO.API.TestHelper.create_recovered([], [])
    recovered2 = OmiseGO.API.TestHelper.create_recovered([{1, 0, 0, %{priv: <<>>}}], [])

    [{:ok, %TransactionDB{txid: txid_1}}, {:ok, %TransactionDB{txid: txid_2}}] =
      TransactionDB.insert(%Block{
        transactions: [
          recovered1,
          recovered2
        ],
        number: txblknum
      })

    expected_transaction_1 = create_expected_transaction(txid_1, recovered1, txblknum, 0)
    expected_transaction_2 = create_expected_transaction(txid_2, recovered2, txblknum, 1)

    assert expected_transaction_1 == delete_meta(TransactionDB.get(txid_1))
    assert expected_transaction_2 == delete_meta(TransactionDB.get(txid_2))
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
