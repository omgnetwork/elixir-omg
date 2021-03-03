defmodule OMG.WatcherInfo.DB.Repo.Migrations.AddTxtypeToTransactionAndOutput do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL
  alias OMG.Watcher.State.Transaction
  alias OMG.WatcherInfo.DB.Repo
  alias OMG.Watcher.WireFormatTypes

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
    :ok = update_transaction_types()
    {_, nil} = update_fee_outputs()
    {_, nil} = update_payment_outputs()
  end

  defp update_transaction_types() do
    Repo
    |> SQL.query!("SELECT txhash, txbytes FROM transactions")
    |> Map.get(:rows)
    |> Enum.reduce(%{}, &reduce_txhash_txbytes/2)
    |> Enum.each(&update_txtype_for_txhashes/1)
  end

  defp reduce_txhash_txbytes([txhash, txbytes], txtype_to_txhashes) do
    %{raw_tx: %{tx_type: txtype}} = Transaction.Signed.decode!(txbytes)

    hashes = case txtype_to_txhashes[txtype] do
      nil -> [txhash]
      hashes -> [txhash | hashes]
    end
    Map.put(txtype_to_txhashes, txtype, hashes)
  end

  defp update_txtype_for_txhashes({txtype, txhashes}) do
    count = length(txhashes)

    {^count, nil} = Repo.update_all(
      from(t in "transactions", where: t.txhash in ^txhashes),
      set: [txtype: txtype]
    )
  end

  defp update_fee_outputs() do
    fee_tx_type = WireFormatTypes.tx_type_for(:tx_fee_token_claim)
    Repo.update_all(
      from(
        o in "txoutputs",
        join: t in "transactions",
        on: o.creating_txhash == t.txhash,
        where: t.txtype == ^fee_tx_type
      ),
      set: [otype: WireFormatTypes.output_type_for(:output_fee_token_claim)]
    )
  end

  defp update_payment_outputs() do
     Repo.update_all(
      from(o in "txoutputs", where: is_nil(o.otype)),
      set: [otype: WireFormatTypes.output_type_for(:output_payment_v1)]
    )
  end
end
