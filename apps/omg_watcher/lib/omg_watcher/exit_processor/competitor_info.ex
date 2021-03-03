# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.ExitProcessor.CompetitorInfo do
  @moduledoc """
  Represents the bulk of information about a competitor to an IFE.

  Internal stuff of `OMG.Watcher.ExitProcessor`
  """

  alias OMG.Watcher.Crypto
  alias OMG.Watcher.State.Transaction
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo

  # mapped by tx_hash
  defstruct [
    :tx,
    # TODO: what if someone does challenges once more but with another input?
    :competing_input_index,
    :competing_input_signature
  ]

  # NOTE: Although `Transaction.Signed` is used here, not all inputs will have signatures in this construct
  #       Still, we do use it, because it is formally correct - it is just not a valid transaction from the POV of
  #       the ledger
  @type t :: %__MODULE__{
          tx: Transaction.Signed.t(),
          competing_input_index: Transaction.input_index_t(),
          competing_input_signature: Crypto.sig_t()
        }

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def make_db_update(
        {tx_hash,
         %__MODULE__{
           tx: tx = %Transaction.Signed{},
           competing_input_index: input_index,
           competing_input_signature: signature
         }}
      )
      when is_integer(input_index) and is_binary(signature) do
    value = %{
      tx: InFlightExitInfo.to_db_value(tx),
      competing_input_index: input_index,
      competing_input_signature: signature
    }

    {:put, :competitor_info, {tx_hash, value}}
  end

  def from_db_kv({tx_hash, %{tx: signed_tx_map, competing_input_index: index, competing_input_signature: signature}})
      when is_map(signed_tx_map) and is_integer(index) and is_binary(signature) do
    tx = InFlightExitInfo.from_db_signed_tx(signed_tx_map)

    competitor_map = %{
      tx: tx,
      competing_input_index: index,
      competing_input_signature: signature
    }

    {tx_hash, struct!(__MODULE__, competitor_map)}
  end

  def new(%{call_data: %{competing_tx: tx_bytes, competing_tx_input_index: index, competing_tx_sig: sig}}),
    do: do_new(tx_bytes, index, sig)

  defp do_new(tx_bytes, competing_input_index, competing_input_signature) do
    with {:ok, %Transaction.Payment{} = raw_tx} <- Transaction.decode(tx_bytes) do
      {Transaction.raw_txhash(raw_tx),
       %__MODULE__{
         tx: %Transaction.Signed{
           raw_tx: raw_tx,
           sigs: [competing_input_signature]
         },
         competing_input_index: competing_input_index,
         competing_input_signature: competing_input_signature
       }}
    end
  end
end
