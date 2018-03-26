defmodule OmisegoWallet.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :addres, :string
      add :amount, :integer
      add :blknum, :integer
      add :oindex, :integer
      add :txbyte, :text
      add :txindex, :integer
    end

  end
end
