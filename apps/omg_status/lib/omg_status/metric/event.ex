# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.Status.Metric.Event do
  @moduledoc """
  A centralised repository of all emitted event types with description.
  """

  @services [
    :challenges_responds_processor,
    :competitor_processor,
    :depositor,
    :exit_challenger,
    :exit_finalizer,
    :exit_processor,
    :exiter,
    :ife_exit_finalizer,
    :in_flight_exit,
    :in_flight_exit_processor,
    :piggyback,
    :piggyback_challenges_processor,
    :piggyback_processor,
    :block_queue
  ]

  @doc """
  :transaction_submission - Child Chain API's received transaction submission.
  :transaction_submission_success - Child Chain API's successful processing of transaction submission.
  :transaction_submission_failed - Child Chain API's failed processing of transaction submission.
  :transaction_submission_failed - Childchain OMG.State mempool transactions
  :pending_transactions - Childchain OMG.State mempool transactions
  :block_transactions - Childchain OMG.State transactions in formed block
  :block_submission_attempt - Childchain Block submission attempted
  :block_submission_success Childchain Block successfully submitted
  :block_submission_gas Child Chain Block queue gas usage metric
  :block_queue_blknum_submitting - Child Chain BlockQueue's blknum of the block being submitted
  :block_queue_blknum_submitted - Child Chain BlockQueue's blknum of the block submitted
  :block_queue_num_blocks_stalled - Child Chain BlockQueue's number of blocks currently being submitted and stalled
  :authority_balance - Child Chain authority address balance
  :balance - OMG.State balance per currency
  :unique_users - OMG.State number of unique_users in the system
  :block_getter_message_queue_len - OMG.Watcher.BlockGetter message queue length
  :watcher_exit_processor_message_queue_len - OMG.Watcher.ExitProcessor message queue length
  :eventer_message_queue_len - OMG.Watcher.Eventer message queue length
  :db_message_queue_len - OMG.DB server implementation (OMG.DB.LevelDB.Server, or OMG.DB.RocksDB.Server,)  message queue length
  :pending_block_queue_length - OMG.WatcherInfo.DB.PendingBlock queue length
  :write - OMG.DB KV layer has three types of actions: write, read,  multiread
  :read - OMG.DB KV layer has three types of actions: write, read,  multiread
  :multiread - OMG.DB KV layer has three types of actions: write, read,  multiread
  @services - We're interested in the events queue length that particular OMG.EthereumEventListener service process
   is handling.  We're interested in the message queue length of particular OMG.EthereumEventListener service process
  """
  def name(:transaction_submission), do: "transaction_submission"
  def name(:transaction_submission_success), do: "transaction_submission_success"
  def name(:transaction_submission_failed), do: "transaction_submission_failed"
  def name(:pending_transactions), do: "pending_transactions"
  def name(:block_transactions), do: "block_transactions"
  def name(:block_submission_attempt), do: "block_submission_attempt"
  def name(:block_submission_success), do: "block_submission_success"
  def name(:block_submission_gas), do: "block_submission_gas"
  def name(:block_queue_blknum_submitting), do: "block_queue_blknum_submitting"
  def name(:block_queue_blknum_submitted), do: "block_queue_blknum_submitted"
  def name(:block_queue_num_blocks_stalled), do: "block_queue_num_blocks_stalled"
  def name(:authority_balance), do: "authority_balance"
  def name(:balance), do: "balance"
  def name(:unique_users), do: "unique_users"
  def name(:block_getter_message_queue_len), do: "block_getter_message_queue_len"
  def name(:watcher_exit_processor_message_queue_len), do: "watcher_exit_processor_message_queue_len"
  def name(:eventer_message_queue_len), do: "eventer_message_queue_len"
  def name(:db_message_queue_len), do: "db_message_queue_len"
  def name(:pending_block_queue_length), do: "pending_block_queue_length"
  def name(:write), do: "db_write"
  def name(:read), do: "db_read"
  def name(:multiread), do: "db_multiread"

  @doc """
    :events - We're interested in the events queue length that particular OMG.EthereumEventListener service process
    is handling.

    message_queue_len -  We're interested in the message queue length of particular OMG.EthereumEventListener service process
  """
  def name(service, :events) when service in @services, do: events_name(service)
  def name(service, :message_queue_len) when service in @services, do: message_queue_len_name(service)

  defp events_name(:depositor), do: "depositor_ethereum_events"
  defp events_name(:in_flight_exit), do: "in_flight_exit_ethereum_events"
  defp events_name(:piggyback), do: "piggyback_ethereum_events"
  defp events_name(:exiter), do: "exiter_ethereum_events"
  defp events_name(:exit_processor), do: "exit_processor_ethereum_events"
  defp events_name(:exit_finalizer), do: "exit_finalizer_ethereum_events"
  defp events_name(:exit_challenger), do: "exit_challenger_ethereum_events"
  defp events_name(:in_flight_exit_processor), do: "in_flight_exit_processor_ethereum_events"
  defp events_name(:piggyback_processor), do: "piggyback_processor_ethereum_events"
  defp events_name(:competitor_processor), do: "competitor_processor_ethereum_events"
  defp events_name(:challenges_responds_processor), do: "challenges_responds_processor_ethereum_events"
  defp events_name(:piggyback_challenges_processor), do: "piggyback_challenges_processor_ethereum_events"
  defp events_name(:ife_exit_finalizer), do: "ife_exit_finalizer_ethereum_events"

  defp message_queue_len_name(:block_queue), do: "block_queue_message_queue_len"
  defp message_queue_len_name(:depositor), do: "depositor_message_queue_len"
  defp message_queue_len_name(:in_flight_exit), do: "in_flight_exit_message_queue_len"
  defp message_queue_len_name(:piggyback), do: "piggyback_message_queue_len"
  defp message_queue_len_name(:exiter), do: "exiter_message_queue_len"
  defp message_queue_len_name(:exit_processor), do: "exit_processor_message_queue_len"
  defp message_queue_len_name(:exit_finalizer), do: "exit_finalizer_message_queue_len"
  defp message_queue_len_name(:exit_challenger), do: "exit_challenger_message_queue_len"
  defp message_queue_len_name(:in_flight_exit_processor), do: "in_flight_exit_processor_message_queue_len"
  defp message_queue_len_name(:piggyback_processor), do: "piggyback_processor_message_queue_len"
  defp message_queue_len_name(:competitor_processor), do: "competitor_processor_message_queue_len"
  defp message_queue_len_name(:challenges_responds_processor), do: "challenges_responds_processor_message_queue_len"
  defp message_queue_len_name(:piggyback_challenges_processor), do: "piggyback_challenges_processor_message_queue_len"
  defp message_queue_len_name(:ife_exit_finalizer), do: "ife_exit_finalizer_message_queue_len"
end
