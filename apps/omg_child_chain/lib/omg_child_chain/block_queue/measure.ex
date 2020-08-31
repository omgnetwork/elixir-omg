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

defmodule OMG.ChildChain.BlockQueue.Measure do
  @moduledoc """
  Counting business metrics sent to Datadog.
  We don't want to pattern match on :ok to Datadog because the connection
  towards the statsd client can be intermittent and sending would be unsuccessful and that
  would trigger the removal of telemetry handler. But because we have monitors in place,
  that eventually recover the connection to Statsd handlers wouldn't exist anymore and metrics
  wouldn't be published.
  """
  require Logger
  import OMG.Status.Metric.Event, only: [name: 2, name: 1]

  alias OMG.ChildChain.BlockQueue
  alias OMG.ChildChain.BlockQueue.Balance
  alias OMG.ChildChain.BlockQueue.GasAnalyzer
  alias OMG.ChildChain.BlockQueue.SubmissionMonitor
  alias OMG.Status.Metric.Datadog

  @supported_events [
    [:process, BlockQueue],
    # Events triggered when a block is submitting or submitted
    [:blknum_submitting, BlockQueue],
    [:blknum_submitted, BlockQueue],
    # Events providing collections of blocks being submitted or stalled
    [:blocks_submitting, SubmissionMonitor],
    [:blocks_stalled, SubmissionMonitor],
    [:gas, GasAnalyzer],
    [:authority_balance, Balance]
  ]
  def supported_events(), do: @supported_events

  def handle_event([:process, BlockQueue], _measurements, _metadata, _config) do
    value =
      self()
      |> Process.info(:message_queue_len)
      |> elem(1)

    _ = Datadog.gauge(name(:block_queue, :message_queue_len), value)
  end

  def handle_event([:gas, GasAnalyzer], %{gas: gas}, _, _config) do
    gwei = div(gas, 1_000_000_000)
    _ = Datadog.gauge(name(:block_submission_gas), gwei)
  end

  def handle_event([:authority_balance, Balance], %{authority_balance: authority_balance}, _, _config) do
    gwei = div(authority_balance, 1_000_000_000)
    _ = Datadog.gauge(name(:authority_balance), gwei)
  end

  def handle_event([:blknum_submitting, BlockQueue], %{blknum: blknum}, _, _config) do
    _ = Datadog.gauge(name(:block_queue_blknum_submitting), blknum)
    _ = Datadog.increment(name(:block_submission_attempt), 1)
  end

  def handle_event([:blknum_submitted, BlockQueue], %{blknum: blknum}, _, _config) do
    _ = Datadog.gauge(name(:block_queue_blknum_submitted), blknum)
    _ = Datadog.increment(name(:block_submission_success), 1)
  end

  def handle_event([:blocks_stalled, SubmissionMonitor], %{blocks: blocks}, _, _config) do
    _ = Datadog.gauge(name(:block_queue_num_blocks_stalled), length(blocks))
  end
end
