defmodule OMG.WatcherInfo.DB.Repo.Migrations.AddTxtypeToTransactionAndOutput do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL
  alias OMG.State.Transaction
  alias OMG.WatcherInfo.DB.Repo

  def up() do
    alter table(:transactions) do
      add :txtype, :integer
    end
    alter table(:txoutputs) do
      add :otype, :integer
    end
    create index(:transactions, :txtype)
    create index(:txoutputs, :otype)
    flush()

    set_txtypes()

    alter table(:transactions) do
      modify(:txtype, :integer, null: false)
    end
    alter table(:txoutputs) do
      modify(:otype, :integer, null: false)
    end
  end

  def down() do
    # This migration only supports outputs of type 1 and 2, we prevent rollback so we
    # don't have problems if new types are introduced in the future.
    raise "can't rollback this migration"
  end

  # Update existing transactions and output that don't have a type
  defp set_txtypes() do
    :ok =
      Repo
      |> SQL.query!("SELECT txhash, txbytes FROM transactions")
      |> Map.get(:rows)
      |> Enum.reduce(%{}, fn [txhash, txbytes], acc ->
        %{raw_tx: %{tx_type: txtype}} = Transaction.Signed.decode!(txbytes)
        hashes = [txhash | acc[txtype] || []]
        Map.put(acc, txtype, hashes)
      end)
      |> Enum.each(fn {txtype, txhashes} ->
        count = length(txhashes)

        {^count, nil} = Repo.update_all(
          from(t in "transactions", where: t.txhash in ^txhashes),
          set: [txtype: txtype]
        )
      end)

    # Fee outputs
    {_, nil} = Repo.update_all(
      from(
        o in "txoutputs",
        join: t in "transactions",
        on: o.creating_txhash == t.txhash,
        where: t.txtype == 3
      ),
      set: [otype: 2]
    )

    # Payment outputs
    {_, nil} = Repo.update_all(
      from(o in "txoutputs", where: is_nil(o.otype)),
      set: [otype: 1]
    )

  end
end
