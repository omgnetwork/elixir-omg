defmodule Engine.UtxoTest do
  use ExUnit.Case, async: true
  doctest Engine.Utxo

  alias Engine.Repo
  alias Engine.Utxo

  describe "changeset/2" do
    test "validates the owner can't be blank" do
      changeset = Utxo.changeset(%Utxo{}, %{})

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:owner]
    end

    test "validates amount can't be zero" do
      changeset = Utxo.changeset(%Utxo{}, %{amount: 0})

      refute changeset.valid?
      assert {"can't be zero", _} = changeset.errors[:amount]
    end

    test "validates owner can't be zero" do
      changeset = Utxo.changeset(%Utxo{}, %{owner: <<0::160>>})

      refute changeset.valid?
      assert {"can't be zero", _} = changeset.errors[:owner]
    end

    test "validates the blknum can't exceed maximum" do
      params = %{blknum: 1_000_000_000_000_000_000, txindex: 0, oindex: 0}
      changeset = Utxo.changeset(%Utxo{}, params)

      refute changeset.valid?
      assert {"can't exceed maximum value", _} = changeset.errors[:blknum]
    end

    test "validates that the utxo position is unique" do
      changeset =
        Utxo.changeset(%Utxo{}, %{
          blknum: 1,
          txindex: 0,
          oindex: 0,
          owner: <<1::160>>,
          amount: 1
        })

      assert changeset.valid?
      Repo.insert(changeset)

      changeset =
        Utxo.changeset(%Utxo{}, %{
          blknum: 1,
          txindex: 0,
          oindex: 0,
          owner: <<1::160>>,
          amount: 1
        })

      # refute changeset.valid? # NB: why doesn't ecto check the unique constraint here?
      assert {:error, _} = Repo.insert(changeset)
    end
  end

  test "set_position/2 builds a utxo position" do
    changeset = Utxo.changeset(%Utxo{}, %{})
    changeset = Utxo.set_position(changeset, %{blknum: 1, txindex: 0, oindex: 0})

    assert 1_000_000_000 == changeset.changes[:pos]
    assert 1 == changeset.changes[:blknum]
    assert 0 == changeset.changes[:txindex]
    assert 0 == changeset.changes[:oindex]
  end
end
