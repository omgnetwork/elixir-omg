defmodule OmiseGOWatcherWeb.Controller.Utxo do
  @moduledoc """
  Operations related to utxo.
  Modify the state in the database.
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.Utxo
  require Utxo
  alias OmiseGOWatcher.UtxoDB

  use OmiseGOWatcherWeb, :controller

  def available(conn, %{"address" => address}) do
    {:ok, address_decode} = Crypto.decode_address(address)

    json(conn, %{
      address: address,
      utxos: encode(UtxoDB.get_utxo(address_decode))
    })
  end

  def compose_utxo_exit(conn, %{"blknum" => blknum, "txindex" => txindex, "oindex" => oindex}) do
    {blknum, ""} = Integer.parse(blknum)
    {txindex, ""} = Integer.parse(txindex)
    {oindex, ""} = Integer.parse(oindex)

    {:ok, composed_utxo_exit} = UtxoDB.compose_utxo_exit(Utxo.position(blknum, txindex, oindex))

    json(conn, encode(composed_utxo_exit))
  end

  defp encode(list) when is_list(list), do: Enum.map(list, &encode/1)

  defp encode(
         %{
           proof: _,
           sigs: _,
           txbytes: _
         } = exit_composition
       ) do
    # TODO smarter encoding (see other TODO in controllers)
    %{
      exit_composition
      | proof: Base.encode16(exit_composition.proof),
        sigs: Base.encode16(exit_composition.sigs),
        txbytes: Base.encode16(exit_composition.txbytes)
    }
  end

  defp encode(%{txbytes: _} = utxo) do
    # TODO smarter encoding (see other TODO in controllers)
    %{
      utxo
      | txbytes: Base.encode16(utxo.txbytes),
        currency: Base.encode16(utxo.currency)
    }
  end
end
