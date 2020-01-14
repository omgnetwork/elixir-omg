# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.WatcherInfo.Factory.DataHelper do
  @moduledoc """
    A data helper module with functions to generate useful data for testing. Unlike the factories,
    the data generated in this module is not constrained to the sructures defined in the DB models.
  """

  defmacro __using__(_opts) do
    quote do
      alias OMG.Eth.Encoding
      alias OMG.Utxo

      require Utxo

      # Generates a certain length of random bytes. Uniqueness not guaranteed so it's not recommended for identifiers.
      def insecure_random_bytes(num_bytes) when num_bytes >= 0 and num_bytes <= 255 do
        0..255 |> Enum.shuffle() |> Enum.take(num_bytes) |> :erlang.list_to_binary()
      end

      def deposit_params(blknum) do
        params_for(:ethevent)
        |> Map.drop([:root_chain_txhash_event, :txoutputs])
        |> Map.merge(%{blknum: blknum, currency: <<0>>, owner: insecure_random_bytes(20), amount: 1})
      end

      def exit_params_from_ethevent(ethevent) do
        [txoutput | _] = ethevent.txoutputs

        %{
          root_chain_txhash: Encoding.to_hex(ethevent.root_chain_txhash),
          log_index: ethevent.log_index,
          call_data: %{
            utxo_pos: Utxo.Position.encode(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))
          }
        }
      end

      def exit_params_from_txoutput(txoutput) do
        ethevent_params = params_for(:ethevent)

        %{
          root_chain_txhash: Encoding.to_hex(ethevent_params.root_chain_txhash),
          log_index: ethevent_params.log_index,
          call_data: %{
            utxo_pos: Utxo.Position.encode(Utxo.position(txoutput.blknum, txoutput.txindex, txoutput.oindex))
          }
        }
      end
    end
  end
end
