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
  use OMG.Watcher.Web, :controller

  alias OMG.API.Crypto
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.UtxoDB
  alias OMG.Watcher.Web.View

  import OMG.Watcher.Web.ErrorHandler

  def available(conn, %{"address" => address}) do
    {:ok, address_decode} = Crypto.decode_address(address)

    available = %{
      address: address,
      utxos: UtxoDB.get_utxo(address_decode)
    }

    render(conn, View.Utxo, :available, available: available)

  end

  def compose_utxo_exit(conn, %{"blknum" => blknum, "txindex" => txindex, "oindex" => oindex}) do
    {blknum, ""} = Integer.parse(blknum)
    {txindex, ""} = Integer.parse(txindex)
    {oindex, ""} = Integer.parse(oindex)

    UtxoDB.compose_utxo_exit(Utxo.position(blknum, txindex, oindex))
    |> respond(conn)

  end

  defp respond({:ok, utxo_exit}, conn) do
    render(conn, View.Utxo, :utxo_exit, utxo_exit: utxo_exit)
  end

  defp respond({:error, code}, conn) do
    handle_error(conn, code)
  end

end
