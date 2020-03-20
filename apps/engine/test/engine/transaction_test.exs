defmodule Engine.TransactionTest do
  use ExUnit.Case, async: true
  doctest Engine.Transaction

  alias Engine.Transaction

  import Engine.Factory

  describe "insert/1" do
    test "validates input utxos exist" do
      {result, changeset} =
        :transaction
        |> params_for(inputs: [build(:input_utxo, blknum: 2)])
        |> Transaction.insert()

      assert :error == result
      assert {"input utxos 2000000000 are missing or spent", _} = changeset.errors[:inputs]
    end

    test "validates input utxos are unspent" do
      %Engine.Utxo{}
      |> Engine.Utxo.changeset(params_for(:input_utxo, blknum: 10))
      |> Engine.Repo.insert()

      {result, changeset} =
        :transaction
        |> params_for(inputs: [build(:spent_utxo, blknum: 10)])
        |> Transaction.insert()

      assert :error == result
      assert {"input utxos 10000000000 are missing or spent", _} = changeset.errors[:inputs]
    end

    test "validates valid owner with rlp" do
      # RLP encoded Transaction with a zero value owner.
      tx_bytes =
        <<248, 80, 1, 193, 0, 246, 245, 1, 243, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 148, 46, 38, 45, 41, 28, 46, 150, 159, 176, 132, 157, 153, 217, 206, 65,
          226, 241, 55, 0, 110, 136, 0, 0, 0, 0, 0, 0, 0, 1, 0, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

      {result, changeset} = Transaction.insert(tx_bytes)

      assert :error == result
      assert {"can't be zero", _} = changeset.errors[:owner]
    end
  end
end
