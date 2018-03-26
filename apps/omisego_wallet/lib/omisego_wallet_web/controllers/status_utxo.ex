defmodule OmisegoWalletWeb.Controller.Utxo do
  alias OmisegoWallet.{Repo, TransactionDB}
  use OmisegoWalletWeb, :controller
  import Ecto.Query, only: [from: 2]
  alias OmiseGO.API.{Block}
  alias OmiseGO.API.State.{Transaction}
  alias OmiseGO.API.State.Transaction.{Signed}

  defp consume_transaction(
         %Signed{
           raw_tx: %Transaction{} = transaction
         } = signed_transaction,
         txindex,
         block_number
       ) do
    # TODO change this to encode from OmiseGo.API.State.Transaction
    txbyte = inspect(signed_transaction)

    make_transaction = fn transaction, number ->
      %TransactionDB{
        addres: Map.get(transaction, :"newowner#{number}"),
        amount: Map.get(transaction, :"amount#{number}"),
        blknum: block_number,
        oindex: 1,
        txbyte: txbyte,
        txindex: txindex
      }
    end

    {Repo.insert(make_transaction.(transaction, "1")),
     Repo.insert(make_transaction.(transaction, "2"))}
  end

  defp remove_transaction(%Signed{
         raw_tx: %Transaction{} = transaction
       }) do
    from(
      transactionDb in TransactionDB,
      where:
        transactionDb.txindex == ^transaction.txindex1 and
          transactionDb.blknum == ^transaction.blknum1 and transactionDb.oindex == 1
    )
    |> Repo.delete_all()

    from(
      transactionDb in TransactionDB,
      where:
        transactionDb.txindex == ^transaction.txindex2 and
          transactionDb.blknum == ^transaction.blknum2 and transactionDb.oindex == 2
    )
    |> Repo.delete_all()
  end

  def consume_block(%Block{transactions: transactions}, block_number) do
    res =
      Stream.with_index(transactions)
      |> Stream.map(fn {%Signed{} = signed, txindex} ->
        {remove_transaction(signed), consume_transaction(signed, txindex, block_number)}
      end)
      |> Enum.to_list()
  end

  def available(conn, %{"addres" => addres}) do
  #  ret =
  #    consume_block(
  #      %Block{
  #        transactions: [
  #          %Signed{
  #            raw_tx: %Transaction{
  #              blknum1: 1,
  #              txindex1: 1,
  #              oindex1: 1,
  #              blknum2: 1,
  #              txindex2: 1,
  #              oindex2: 1,
  #              newowner1: "edek",
  #              amount1: 23,
  #              newowner2: "plus",
  #              amount2: 11,
  #              fee: 3
  #            }
  #          },
  #          %Signed{
  #            raw_tx: %Transaction{
  #              blknum1: 2,
  #              txindex1: 1,
  #              oindex1: 1,
  #              blknum2: 1,
  #              txindex2: 1,
  #              oindex2: 1,
  #              newowner1: "anakonda",
  #              amount1: 23,
  #              newowner2: "anakonda",
  #              amount2: 11,
  #              fee: 3
  #            }
  #          }
  #        ]
  #      },
  #      2
  #    )
  #
    # json(conn, ret)
    # Repo.delete(%TransactionDB{addres: "anakonda", amount: 11})
    json(conn, %{addres: addres, utxos: get_all_utxo(addres)})
  end

  defp get_all_utxo(addres) do
    transactions = Repo.all(from(tr in TransactionDB, where: tr.addres == ^addres, select: tr))
    slicer = &Map.take(&1, TransactionDB.field_names())
    Enum.map(transactions, slicer)
  end
end
