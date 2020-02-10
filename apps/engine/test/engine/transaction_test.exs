defmodule Engine.TransactionTest do
  use ExUnit.Case, async: true
  doctest Engine.Transaction

  alias Engine.Transaction
  alias ExPlasma.Transaction.Deposit

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

      {:ok, output} =
        ExPlasma.Utxo.new(%ExPlasma.Utxo{owner: <<1::160>>, currency: <<0::160>>, amount: 1})

      {:ok, payment} = ExPlasma.Transaction.Payment.new(%{inputs: [input], outputs: [output]})

      changeset = Engine.Transaction.changeset(%Engine.Transaction{}, payment)

      refute changeset.valid?
      assert {"missing/spent input positions for 2000000000", _} = changeset.errors[:inputs]
    end

    test "validates a transaction from rlp" do
      {:ok, deposit} =
        Deposit.new(%ExPlasma.Utxo{owner: <<1::160>>, currency: <<0::160>>, amount: 1})

      tx_bytes = deposit |> ExPlasma.encode()
      changeset = Transaction.changeset(%Transaction{}, tx_bytes)
      output = hd(changeset.changes[:outputs])

      assert 1 == output.changes[:amount]
      assert <<1::160>> == output.changes[:owner]
    end

    test "changeset includes an error for invalid rlp" do
      # RLP encoded Transaction with a zero value owner.
      tx_bytes =
        <<248, 80, 1, 193, 0, 246, 245, 1, 243, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 148, 46, 38, 45, 41, 28, 46, 150, 159, 176, 132, 157, 153, 217, 206, 65,
          226, 241, 55, 0, 110, 136, 0, 0, 0, 0, 0, 0, 0, 1, 0, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

      changeset = Transaction.changeset(%Transaction{}, tx_bytes)

      refute changeset.valid?
      assert {"can't be zero", _} = changeset.errors[:owner]
    end
  end
end
