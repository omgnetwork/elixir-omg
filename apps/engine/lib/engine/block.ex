defmodule Engine.Block do
  @moduledoc """
  Represent a block of transactions that will be submitted to the contracts.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "blocks" do
    field(:hash, :binary)
    field(:number, :integer)

    has_many(:transactions, Engine.Transaction)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Forms a pending block record based on the existing pending transactions. This
  attaches free transactions into a new block, awaiting for submission to the contract
  later on.
  """
  @spec form_block() :: {non_neg_integer, non_neg_integer}
  def form_block() do
    # NB: We grab the query first and return the IDs to work around ecto's
    # update_all not being able to accept `limit`.
    query = from(t in Engine.Transaction, where: is_nil(t.block_id), limit: 25)
    txn_ids = query |> Engine.Repo.all() |> Enum.map(& &1.id)
    pending_query = from(t in Engine.Transaction, where: t.id in ^txn_ids)

    # Create a new Block for us to map to.
    {:ok, block} = Engine.Repo.insert(%__MODULE__{})

    # NB: We explicitly bump the updated_at field here as update_all does not
    # do that for us.
    {total_records, _} =
      Engine.Repo.update_all(pending_query,
        set: [
          block_id: block.id,
          updated_at: NaiveDateTime.utc_now()
        ]
      )

    {block.id, total_records}
  end
end
