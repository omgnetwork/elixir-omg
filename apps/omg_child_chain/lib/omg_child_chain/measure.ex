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
  Counting business metrics sent to Datadog
  """

  alias OMG.Status.Metric.Datadog

  @txn_submission :txn_submission
  @txn_submission_success :txn_submission_success
  @txn_submission_error :txn_submission_error

  @supported_events [
    [@txn_submission, OMG.ChildChain],
    [@txn_submission_success, OMG.ChildChain],
    [@txn_submission_error, OMG.ChildChain]
  ]
  def supported_events(), do: @supported_events

  def handle_event([@txn_submission, OMG.ChildChain], event_value, _event_metadata, _config) do
    Datadog.increment(@txn_submission, event_value, tags: ["OMG.ChildChain.submit"])
  end

  def handle_event([@txn_submission_success, OMG.ChildChain], event_value, _event_metadata, _config) do
    Datadog.increment(@txn_submission_success, event_value, tags: ["OMG.ChildChain.submit", "success"])
  end

  def handle_event([@txn_submission_error, OMG.ChildChain], event_value, _event_metadata, _config) do
    Datadog.increment(@txn_submission_error, event_value, tags: ["OMG.ChildChain.submit", "error"])
  end
end
