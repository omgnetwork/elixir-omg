defmodule Engine.TransactionTest do
  use ExUnit.Case, async: true
  doctest Engine.Transaction

  alias Engine.Transaction
  alias Engine.Utxo
  alias ExPlasma.Transaction.Deposit

  describe "build/1" do
    test "creates a deposit transaction" do
      {:ok, deposit} = Deposit.new(%ExPlasma.Utxo{owner: <<1::160>>, currency: <<0::160>>, amount: 1})
      # FIXME: fix ex_plasma or here for better defaults
      deposit = %{deposit | tx_type: 1, tx_data: 0, metadata: <<0::160>>}
      changeset = Transaction.build(deposit)
      output = hd(changeset.changes[:outputs])

      assert 1 == output.changes[:amount]
      assert <<1::160>> == output.changes[:owner]
    end
  end
end
