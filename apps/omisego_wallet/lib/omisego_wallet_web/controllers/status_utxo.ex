defmodule OmisegoWalletWeb.Controller.Utxo do

  defmodule Transaction do
    @moduledoc"""
    """
    @type t :: %Transaction{
            blknum: integer,
            txindex: integer,
            oindex: integer,
            txbyte: bitstring,
            fee: integer
          }
    defstruct [:blknum, :txindex, :oindex, :txbyte, :fee]
  end

  defmodule Transactions do
    @moduledoc""" 
    """
    @type t :: %Transactions{addres: bitstring, utxos: list(Transaction.t)}
    defstruct [:addres, :utxos]
  end

  @spec get_all_utxo(bitstring) :: Transactions.t()
  def get_all_utxo(addres) do
    %Transactions{
      addres: addres,
      utxos: [
        %Transaction{blknum: 23, txindex: 12, oindex: 1, txbyte: "ba32rffaa45235235", fee: 23},
        %Transaction{blknum: 23, txindex: 12, oindex: 1, txbyte: "ba32rffada45235235", fee: 23},
        %Transaction{blknum: 23, txindex: 12, oindex: 1, txbyte: "ba32rffaa4523ddd5235", fee: 23}
      ]
    }
  end

  use OmisegoWalletWeb, :controller

  def available(conn, %{"addres" => addres}) do
    json(conn, get_all_utxo(addres))
  end
end
