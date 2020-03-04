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

  # <prefix>.[<subprefix>.]<instrumented_section>.<target (noun)>.<action (past tense verb)>
  @txn_submission_submitted :"omg.childchain.transaction.submission.submitted"
  def txn_submission_submitted(), do: @txn_submission_submitted

  @txn_submission_succeeded :"omg.childchain.transaction.submission.succeeded"
  def txn_submission_succeeded(), do: @txn_submission_succeeded

  @txn_submission_failed :"omg.childchain.transaction.submission.failed"
  def txn_submission_failed(), do: @txn_submission_failed

  @supported_events [[@txn_submission_submitted], [@txn_submission_succeeded], [@txn_submission_failed]]
  def supported_events(), do: @supported_events

  def handle_event(@txn_submission_submitted, event_measurements, _event_metadata, _config) do
    IO.puts("************** handle_event(): '#{@txn_submission_submitted}' **************")
    IO.inspect(event_measurements, label: "event_measurements")
    IO.inspect(_event_metadata, label: "_event_metadata")
    IO.inspect(_config, label: "_config")
    Datadog.increment(to_string(@txn_submission_submitted), increment_by_amount(event_measurements))
  end

  def handle_event(@txn_submission_succeeded, event_measurements, _event_metadata, _config) do
    IO.puts("************** handle_event(): '#{@txn_submission_succeeded}' **************")
    IO.inspect(event_measurements, label: "event_measurements")
    IO.inspect(_event_metadata, label: "_event_metadata")
    IO.inspect(_config, label: "_config")
    Datadog.increment(to_string(@txn_submission_succeeded), increment_by_amount(event_measurements))
  end

  def handle_event(@txn_submission_failed, event_measurements, _event_metadata, _config) do
    IO.puts("************** handle_event(): '#{@txn_submission_failed}' **************")
    IO.inspect(event_measurements, label: "event_measurements")
    IO.inspect(_event_metadata, label: "_event_metadata")
    IO.inspect(_config, label: "_config")
    Datadog.increment(to_string(@txn_submission_failed), increment_by_amount(event_measurements))
  end

  def handle_event([@txn_submission_error, OMG.ChildChain], event_value, _event_metadata, _config) do
    Datadog.increment(@txn_submission_error, event_value, tags: ["OMG.ChildChain.submit", "error"])
  end
end
