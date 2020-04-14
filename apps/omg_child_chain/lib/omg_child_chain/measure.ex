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

defmodule OMG.ChildChain.Measure do
  @moduledoc """
  Collects business metrics and sends to Datadog.
  """
  import OMG.Status.Metric.Event, only: [name: 1]

  alias OMG.ChildChain.API.Transaction, as: TransactionAPI
  alias OMG.Status.Metric.Datadog

  @supported_events [
    [:submit, TransactionAPI],
    [:submit_success, TransactionAPI],
    [:submit_failed, TransactionAPI]
  ]

  def supported_events(), do: @supported_events

  def handle_event([:submit, TransactionAPI], _measurements, _metadata, _config) do
    _ = Datadog.increment(name(:transaction_submission), 1)
  end

  def handle_event([:submit_success, TransactionAPI], _, _metadata, _config) do
    _ = Datadog.increment(name(:transaction_submission_success), 1)
  end

  def handle_event([:submit_failed, TransactionAPI], _, _metadata, _config) do
    _ = Datadog.increment(name(:transaction_submission_failed), 1)
  end
end
