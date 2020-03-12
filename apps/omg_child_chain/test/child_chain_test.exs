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
defmodule OMG.ChildChainTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias OMG.ChildChain
  alias OMG.ChildChain.Transaction.Metrics

  @valid_transaction 1
  @invalid_transaction 2
  @error_transaction 3
  @exception_transaction 4

  defmodule TestSubmitter do
    @moduledoc """
    A test module for implmenting OMG.ChildChain.Transaction.Submitter behavior for testing
    purposes.
    """
    @behaviour OMG.ChildChain.Transaction.Submitter

    @impl OMG.ChildChain.Transaction.Submitter
    def submit(transaction) do
      case transaction do
        1 -> {:ok, %{txhash: 0, blknum: 1, txindex: 0}}
        2 -> {:error, :transaction_not_supported}
        3 -> raise "error during transaction validation"
        4 -> throw("exception during transaction validation")
      end
    end
  end

  setup do
    config = %{tags: ["foo:bar"]}
    apply(:telemetry, :attach_many, Metrics.events_handler(config))

    pid = :erlang.pid_to_list(self())

    {:ok, dd_pid} = start_supervised(OMG.Status.Metric.Datadog, dd_listener_pid: pid)

    on_exit(fn ->
      :ok = :telemetry.detach(Metrics.handler_id())
    end)
  end

  describe "submit/2" do
    test "submit sends a submission success metric to datadog when transaction submission succeeds" do
      assert ChildChain.submit(@valid_transaction, TestSubmitter) == {:ok, %{txhash: 0, blknum: 1, txindex: 0}}

      transaction_submit_event = Submit.transaction_submit_event()
      assert_receive({:counter, transaction_submit_event, 1, _})
    end

    test "submit sends a submission failure metric to datadog when transaction submission fails" do
      assert ChildChain.submit(@invalid_transaction, TestSubmitter) == {:error, :transaction_not_supported}
    end

    test "submit sends a submission failure metric to datadog when transaction submission raises error" do
      assert_raise(
        RuntimeError,
        "error during transaction validation",
        fn -> ChildChain.submit(@error_transaction, TestSubmitter) end
      )
    end

    test "submit sends a submission failure metric to datadog when transaction submission throws exception" do
      assert catch_throw(ChildChain.submit(@exception_transaction, TestSubmitter)) ==
               "exception during transaction validation"
    end
  end
end
