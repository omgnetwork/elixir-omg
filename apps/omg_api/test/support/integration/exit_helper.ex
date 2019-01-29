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

defmodule OMG.API.Integration.ExitHelper do
  @moduledoc """
  Common helper functions that are useful when integration-testing the child chain and watcher requiring exits
  """

  alias OMG.API.Block
  alias OMG.API.Crypto
  alias OMG.API.State.Core
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  require OMG.API.Utxo

  @spec compose_utxo_exit([binary()], Utxo.Position.t()) :: Core.exit_t()
  def compose_utxo_exit(txs, {blknum, txindex, oindex}) do
    proof =
      txs
      |> Enum.map(&Crypto.hash/1)
      |> Block.create_tx_proof(txindex)

    {:ok,
     %Transaction.Signed{
       raw_tx: raw_tx,
       sigs: sigs
     }} =
      txs
      |> Enum.at(txindex)
      |> hex_decode()
      |> Transaction.Signed.decode()

    utxo_pos = Utxo.position(blknum, txindex, oindex) |> Utxo.Position.encode()
    %{
      utxo_pos: utxo_pos,
      txbytes: Transaction.encode(raw_tx),
      proof: proof,
      sigs: Enum.join(sigs)
    }
  end

  defp hex_decode(hex) do
    {:ok, bytes} = OMG.RPC.Web.Encoding.from_hex(hex)
    bytes
  end
end
