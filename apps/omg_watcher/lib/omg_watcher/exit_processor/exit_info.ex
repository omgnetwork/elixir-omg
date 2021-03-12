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

defmodule OMG.Watcher.ExitProcessor.ExitInfo do
  @moduledoc """
  Represents the bulk of information about a tracked exit.

  Internal stuff of `OMG.Watcher.ExitProcessor`
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utxo
  alias OMG.Watcher.Event

  require Utxo

  @enforce_keys [
    :amount,
    :currency,
    :owner,
    :exit_id,
    :exiting_txbytes,
    :is_active,
    :eth_height,
    :root_chain_txhash,
    :scheduled_finalization_time,
    :block_timestamp,
    :spending_txhash
  ]

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
          eth_height: pos_integer(),
          root_chain_txhash: Transaction.tx_hash() | nil,
          scheduled_finalization_time: pos_integer() | nil,
          block_timestamp: pos_integer() | nil,
          spending_txhash: Transaction.tx_hash() | nil
        }

  @spec new(map(), map()) :: t()
  def new(contract_status, exit_event) do
    %{
      eth_height: eth_height,
      output_tx: txbytes,
      exit_id: exit_id,
      root_chain_txhash: root_chain_txhash,
      scheduled_finalization_time: scheduled_finalization_time,
      block_timestamp: block_timestamp
    } = exit_event

    Utxo.position(_, _, oindex) = utxo_pos_for(exit_event)
    {:ok, raw_tx} = Transaction.decode(txbytes)
    %{amount: amount, currency: currency, owner: owner} = raw_tx |> Transaction.get_outputs() |> Enum.at(oindex)

    do_new(contract_status,
      amount: amount,
      currency: currency,
      owner: owner,
      exit_id: exit_id,
      exiting_txbytes: txbytes,
      eth_height: eth_height,
      root_chain_txhash: root_chain_txhash,
      scheduled_finalization_time: scheduled_finalization_time,
      block_timestamp: block_timestamp,
      spending_txhash: nil
    )
  end

  def new_key(exit_info), do: utxo_pos_for(exit_info)

  defp utxo_pos_for(%{utxo_pos: utxo_pos_enc} = _exit_info), do: Utxo.Position.decode!(utxo_pos_enc)

  @spec do_new(map(), list(keyword())) :: t()
  defp do_new(contract_status, fields) do
    fields = Keyword.put_new(fields, :is_active, parse_contract_exit_status(contract_status))
    struct!(__MODULE__, fields)
  end

  @spec make_event_data(Event.module_t(), Utxo.Position.t(), t()) :: struct()
  def make_event_data(type, position, exit_info) do
    struct(
      type,
      exit_info |> Map.from_struct() |> Map.put(:utxo_pos, Utxo.Position.encode(position))
    )
  end

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  @spec make_db_update({Utxo.Position.t(), t()}) :: {:put, :exit_info, {Utxo.Position.db_t(), map()}}
  def make_db_update({position, exit_info}) do
    value = %{
      amount: exit_info.amount,
      currency: exit_info.currency,
      owner: exit_info.owner,
      exit_id: exit_info.exit_id,
      exiting_txbytes: exit_info.exiting_txbytes,
      is_active: exit_info.is_active,
      eth_height: exit_info.eth_height,
      root_chain_txhash: exit_info.root_chain_txhash,
      scheduled_finalization_time: exit_info.scheduled_finalization_time,
      block_timestamp: exit_info.block_timestamp
    }

    {:put, :exit_info, {Utxo.Position.to_db_key(position), value}}
  end

  @spec from_db_kv({Utxo.Position.db_t(), map()}) :: {Utxo.Position.t(), t()}
  def from_db_kv({db_utxo_pos, exit_info}) do
    # mapping is used in case of changes in data structure
    value = %{
      amount: exit_info.amount,
      currency: exit_info.currency,
      owner: exit_info.owner,
      exit_id: exit_info.exit_id,
      exiting_txbytes: exit_info.exiting_txbytes,
      is_active: exit_info.is_active,
      eth_height: exit_info.eth_height,
      spending_txhash: nil,
      # defaults value to nil if non-existent in the DB.
      root_chain_txhash: Map.get(exit_info, :root_chain_txhash),
      scheduled_finalization_time: Map.get(exit_info, :scheduled_finalization_time),
      block_timestamp: Map.get(exit_info, :block_timestamp)
    }

    {Utxo.Position.from_db_key(db_utxo_pos), struct!(__MODULE__, value)}
  end

  # processes the return value of `Eth.get_standard_exit_structs(exit_ids)`
  #     struct StandardExit {
  #     bool exitable;
  #     uint256 utxoPos;
  #     bytes32 outputId;
  #     address payable exitTarget;
  #     uint256 amount;
  #     uint256 bondSize;
  #     uint256 bountySize;
  # }
  # `exitable` will be `false` if the exit was challenged
  # `exitable` will be `false` ALONG WITH the whole tuple holding zeroees, if the exit was processed successfully
  # **NOTE** one can only rely on the zero-nonzero of this data, since for processed exits this data will be all zeros
  defp parse_contract_exit_status({exitable, _, _, _, _, _, _}), do: exitable

  # Based on the block number determines whether UTXO was created by a deposit.
  defguardp is_deposit(blknum, child_block_interval) when rem(blknum, child_block_interval) != 0

  @doc """
  Calculates the time at which an exit can be processed and released if not challenged successfully.
  See https://docs.omg.network/challenge-period for calculation logic.
  """
  @spec calculate_sft(
          blknum :: pos_integer(),
          exit_block_timestamp :: pos_integer(),
          utxo_creation_timestamp :: pos_integer(),
          min_exit_period :: pos_integer(),
          child_block_interval :: pos_integer()
        ) ::
          {:ok, pos_integer()}
  def calculate_sft(blknum, exit_block_timestamp, utxo_creation_timestamp, min_exit_period, child_block_interval) do
    case is_deposit(blknum, child_block_interval) do
      true ->
        {:ok, max(exit_block_timestamp + min_exit_period, utxo_creation_timestamp + min_exit_period)}

      false ->
        {:ok, max(exit_block_timestamp + min_exit_period, utxo_creation_timestamp + 2 * min_exit_period)}
    end
  end
end
