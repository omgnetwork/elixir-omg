defmodule OmiseGOWatcher.Challenger.CoreTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.Transaction
  alias OmiseGO.API.State.Transaction.Signed
  alias OmiseGOWatcher.Challenger.Challenge
  alias OmiseGOWatcher.Challenger.Core
  alias OmiseGOWatcher.TestHelper
  alias OmiseGOWatcher.TransactionDB

  deffixture transactions do
    [
      create_transaction(1, 5, 0),
      create_transaction(2, 0, 4)
    ]
  end

  defp create_transaction(txindex, amount1, amount2) do
    signed = %Signed{
      raw_tx: %Transaction{
        blknum1: 1,
        txindex1: 0,
        oindex1: 0,
        blknum2: 1,
        txindex2: 0,
        oindex2: 1,
        cur12: <<0::160>>,
        newowner1: "alice",
        amount1: amount1,
        newowner2: "bob",
        amount2: amount2
      },
      sig1: "sig1",
      sig2: "sig2"
    }

    txid = Signed.signed_hash(signed)

    %TransactionDB{
      blknum1: 1,
      txindex1: 0,
      oindex1: 0,
      blknum2: 1,
      txindex2: 0,
      oindex2: 1,
      cur12: <<0::160>>,
      newowner1: "",
      amount1: amount1,
      newowner2: "",
      amount2: amount2,
      txblknum: 2,
      txindex: txindex,
      txid: txid,
      sig1: "sig1",
      sig2: "sig2"
    }
  end

  @tag fixtures: [:transactions]
  test "creates a challenge for an exit", %{transactions: transactions} do
    utxo_exit = %{blknum: 1, txindex: 0, oindex: 0}
    offending_tx = hd(transactions)
    expected_cutxopos = TestHelper.utxo_pos(2, 1, 0)

    %Challenge{cutxopos: ^expected_cutxopos, eutxoindex: 0} =
      Core.create_challenge(offending_tx, transactions, utxo_exit)

    offending_tx = hd(tl(transactions))
    expected_cutxopos = TestHelper.utxo_pos(2, 2, 1)

    %Challenge{cutxopos: ^expected_cutxopos, eutxoindex: 0} =
      Core.create_challenge(offending_tx, transactions, utxo_exit)
  end
end
