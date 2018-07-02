defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API.Block
  alias OmiseGO.API.State.{Transaction, Transaction.Recovered}
  alias OmiseGOWatcher.TransactionDB

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "insert and retrive transaction" do
    txblknum = 0
    txindex = 0
    recovered = OmiseGO.API.TestHelper.create_recovered([], Transaction.zero_address(), [])
    {:ok, %TransactionDB{txid: id}} = TransactionDB.insert(recovered, txblknum, txindex)
    expected_transaction = create_expected_transaction(id, recovered, txblknum, txindex)
    assert expected_transaction == delete_meta(TransactionDB.get(id))
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
  test "insert and retrive block of transactions ", %{alice: alice, bob: bob} do
    txblknum = 0
    recovered1 = OmiseGO.API.TestHelper.create_recovered([{2, 3, 1, bob}], Transaction.zero_address(), [{alice, 200}])
    recovered2 = OmiseGO.API.TestHelper.create_recovered([{1, 0, 0, alice}], Transaction.zero_address(), [])

    [{:ok, %TransactionDB{txid: txid_1}}, {:ok, %TransactionDB{txid: txid_2}}] =
      TransactionDB.insert(%Block{
        transactions: [
          recovered1,
          recovered2
        ],
        number: txblknum
      })

    assert create_expected_transaction(txid_1, recovered1, txblknum, 0) == delete_meta(TransactionDB.get(txid_1))
    assert create_expected_transaction(txid_2, recovered2, txblknum, 1) == delete_meta(TransactionDB.get(txid_2))
  end

  defp create_expected_transaction(
         txid,
         %Recovered{raw_tx: transaction} = tx,
         txblknum,
         txindex
       ) do
    {sig1, sig2} = Recovered.get_sigs(tx)

    %TransactionDB{
      txblknum: txblknum,
      txindex: txindex,
      txid: txid,
      sig1: sig1,
      sig2: sig2
    }
    |> Map.merge(Map.from_struct(transaction))
    |> delete_meta
  end

  defp delete_meta(%TransactionDB{} = transaction) do
    Map.delete(transaction, :__meta__)
  end
end
