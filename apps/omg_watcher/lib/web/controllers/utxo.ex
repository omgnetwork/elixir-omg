# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.Web.Controller.Utxo do
  @moduledoc """
  Operations related to utxo.
  Modify the state in the database.
  """

  alias OMG.API.Crypto
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.UtxoDB

  use OMG.Watcher.Web, :controller

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
    # FIXME smarter encoding (see other FIXME in controllers)
    %{
      exit_composition
      | proof: Base.encode16(exit_composition.proof),
        sigs: Base.encode16(exit_composition.sigs),
        txbytes: Base.encode16(exit_composition.txbytes)
    }
  end

  defp encode(%{txbytes: _} = utxo) do
    # FIXME smarter encoding (see other FIXME in controllers)
    %{
      utxo
      | txbytes: Base.encode16(utxo.txbytes),
        currency: Base.encode16(utxo.currency)
    }
  end
end
