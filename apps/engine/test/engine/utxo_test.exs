defmodule Engine.UtxoTest do
  use ExUnit.Case, async: true
  doctest Engine.Utxo

  alias Engine.Utxo

  describe "input_changeset/2" do
    test "sets the utxo position" do
      params = %{blknum: 1, txindex: 0, oindex: 0}
      changeset = Utxo.input_changeset(%Utxo{}, params)

      assert changeset.valid?
      assert 1_000_000_000 == changeset.changes[:pos]
    end

    test "validates the blknum cannot be too large" do
      params = %{blknum: 1_000_000_000_000_000_000, txindex: 0, oindex: 0}
      changeset = Utxo.input_changeset(%Utxo{}, params)

      refute changeset.valid?
      assert {"can't exceed maximum value", _} = changeset.errors[:blknum]
    end
  end

  describe "output_changeset/2" do
    test "validates the owner cannot be blank" do
      changeset = Utxo.output_changeset(%Utxo{}, %{})

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:owner]
    end

    test "validates amount cannot be zero" do
      params = %{
        output_type: 1,
        owner: <<1::160>>,
        currency: <<0::160>>,
        amount: 0
      }

      changeset = Utxo.output_changeset(%Utxo{}, params)

      refute changeset.valid?
      assert {"can't be zero", _} = changeset.errors[:amount]
    end

    test "validates owner cannot be zero" do
      params = %{
        output_type: 1,
        owner: <<0::160>>,
        currency: <<0::160>>,
        amount: 0
      }

      changeset = Utxo.output_changeset(%Utxo{}, params)

      refute changeset.valid?
      assert {"can't be zero", _} = changeset.errors[:owner]
    end
  end
end
