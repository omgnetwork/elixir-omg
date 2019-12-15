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

defmodule OMG.Watcher.ExitProcessor.ExitInfo do
  @moduledoc """
  Represents the bulk of information about a tracked exit.

  Internal stuff of `OMG.Watcher.ExitProcessor`
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @enforce_keys [:amount, :currency, :owner, :exit_id, :exiting_txbytes, :is_active, :eth_height]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          amount: non_neg_integer(),
          currency: Crypto.address_t(),
          owner: Crypto.address_t(),
          exit_id: non_neg_integer(),
          # the transaction creating the exiting output
          exiting_txbytes: Transaction.tx_bytes(),
          # this means the exit has been first seen active. If false, it won't be considered harmful
          is_active: boolean(),
          eth_height: pos_integer()
        }

  def new(contract_status, %{eth_height: eth_height, call_data: %{output_tx: txbytes}, exit_id: exit_id} = event) do
    Utxo.position(_, _, oindex) = utxo_pos_for(event)
    {:ok, raw_tx} = Transaction.decode(txbytes)
    %{amount: amount, currency: currency, owner: owner} = raw_tx |> Transaction.get_outputs() |> Enum.at(oindex)

    do_new(contract_status,
      amount: amount,
      currency: currency,
      owner: owner,
      exit_id: exit_id,
      exiting_txbytes: txbytes,
      eth_height: eth_height
    )
  end

  def new_key(_contract_status, event),
    do: utxo_pos_for(event)

  defp utxo_pos_for(%{call_data: %{utxo_pos: utxo_pos_enc}} = _event),
    do: Utxo.Position.decode!(utxo_pos_enc)

  defp do_new(contract_status, fields) do
    fields = Keyword.put_new(fields, :is_active, parse_contract_exit_status(contract_status))
    struct!(__MODULE__, fields)
  end

  def make_event_data(type, position, %__MODULE__{} = exit_info) do
    struct(type, exit_info |> Map.from_struct() |> Map.put(:utxo_pos, Utxo.Position.encode(position)))
  end

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def make_db_update(
        {position,
         %__MODULE__{
           amount: amount,
           currency: currency,
           owner: owner,
           exit_id: exit_id,
           exiting_txbytes: exiting_txbytes,
           is_active: is_active,
           eth_height: eth_height
         }}
      )
      when is_integer(amount) and is_integer(eth_height) and
             is_binary(currency) and is_binary(owner) and is_integer(exit_id) and is_binary(exiting_txbytes) and
             is_boolean(is_active) do
    value = %{
      amount: amount,
      currency: currency,
      owner: owner,
      exit_id: exit_id,
      exiting_txbytes: exiting_txbytes,
      is_active: is_active,
      eth_height: eth_height
    }

    {:utxo_position, blknum, txindex, oindex} = position
    {:put, :exit_info, {{blknum, txindex, oindex}, value}}
  end

  def from_db_kv(
        {db_utxo_pos,
         %{
           amount: amount,
           currency: currency,
           owner: owner,
           exit_id: exit_id,
           exiting_txbytes: exiting_txbytes,
           is_active: is_active,
           eth_height: eth_height
         }}
      )
      when is_integer(amount) and is_integer(eth_height) and
             is_binary(currency) and is_binary(owner) and is_integer(exit_id) and is_binary(exiting_txbytes) and
             is_boolean(is_active) do
    # mapping is used in case of changes in data structure
    value = %{
      amount: amount,
      currency: currency,
      owner: owner,
      exit_id: exit_id,
      exiting_txbytes: exiting_txbytes,
      is_active: is_active,
      eth_height: eth_height
    }

    {blknum, txindex, oindex} = db_utxo_pos
    {{:utxo_position, blknum, txindex, oindex}, struct!(__MODULE__, value)}
  end

  # processes the return value of `Eth.get_standard_exits_structs(exit_id)`
  # `exitable` will be `false` if the exit was challenged
  # `exitable` will be `false` ALONG WITH the whole tuple holding zeroees, if the exit was processed successfully
  # **NOTE** one can only rely on the zero-nonzero of this data, since for processed exits this data will be all zeros
  defp parse_contract_exit_status({exitable, _, _, _, _, _}), do: exitable
end
