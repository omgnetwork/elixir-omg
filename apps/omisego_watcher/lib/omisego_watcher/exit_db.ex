defmodule OmiseGOWatcher.ExitDB do
  @moduledoc"""
  Ecto schema for exit
  """
  use Ecto.Schema

  alias OmiseGOWatcher.Repo

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @field_names [:blknum, :txindex, :oindex, :owner]
  def field_names, do: @field_names

  schema "exits" do
    field(:blknum, :integer)
    field(:txindex, :integer)
    field(:oindex, :integer)
    field(:owner, :string)
  end

  def exit_exists(%{blknum: blknum, txindex: txindex, oindex: oindex, owner: owner}) do
    query = from(
        utxo_exit in __MODULE__,
        where:
          utxo_exit.blknum == ^blknum and utxo_exit.txindex == ^txindex and
            utxo_exit.oindex == ^oindex and utxo_exit.owner == ^owner
      )
    case Repo.one(query) do
      nil -> :exit_does_not_exist
      _ -> :exit_exists
    end
  end

  def insert_exit(%{blknum: blknum, txindex: txindex, oindex: oindex, owner: owner}) do
    insert = Repo.insert(%__MODULE__{
      blknum: blknum,
      txindex: txindex,
      oindex: oindex,
      owner: owner
    })

    case insert do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :failed_to_insert_exit}
    end
  end

  def changeset(utxo_db, attrs) do
    utxo_db
    |> cast(attrs, @field_names)
    |> validate_required(@field_names)
  end
end
