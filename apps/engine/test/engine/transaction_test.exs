defmodule Engine.TransactionTest do
  use ExUnit.Case, async: true
  doctest Engine.Transaction

  alias Engine.Transaction
  alias Engine.Utxo
  alias ExPlasma.Transaction.Deposit

  describe "build/1" do
    test "creates a deposit transaction" do
      {:ok, deposit} = Deposit.new(%ExPlasma.Utxo{owner: <<1::160>>, currency: <<0::160>>, amount: 1})

      deposit = %{deposit | tx_type: 1, tx_data: 0, metadata: <<0::160>>}
      changeset = Transaction.build(deposit)
      output = hd(changeset.changes[:outputs])

      assert 1 == output.changes[:amount]
      assert <<1::160>> == output.changes[:owner]
    end

    test "creates a transaction from rlp" do
      {:ok, deposit} = Deposit.new(%ExPlasma.Utxo{owner: <<1::160>>, currency: <<0::160>>, amount: 1})

      changeset = deposit |> ExPlasma.encode() |> Transaction.build()
      output = hd(changeset.changes[:outputs])

      assert 1 == output.changes[:amount]
      assert <<1::160>> == output.changes[:owner]
    end
  end

  describe "changeset/2" do
    test "validates transactions against non-existing utxo inputs" do
      {:ok, input} =
        ExPlasma.Utxo.new(%ExPlasma.Utxo{
          blknum: 2,
          txindex: 0,
          oindex: 0,
          owner: <<1::160>>,
          currency: <<0::160>>,
          amount: 1
        })

      {:ok, output} = ExPlasma.Utxo.new(%ExPlasma.Utxo{owner: <<1::160>>, currency: <<0::160>>, amount: 1})

      {:ok, payment} = ExPlasma.Transaction.Payment.new(%{inputs: [input], outputs: [output]})

      changeset = Engine.Transaction.changeset(%Engine.Transaction{}, payment)

      refute changeset.valid?
      assert {"missing/spent input positions for 2000000000", _} = changeset.errors[:inputs]
    end
  end
end
