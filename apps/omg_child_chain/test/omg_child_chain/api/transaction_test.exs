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

defmodule OMG.ChildChain.API.TransactionTest do
  use ExUnit.Case, async: true
  alias OMG.ChildChain.API.Transaction

  @child_chain __MODULE__.MockChildChain
  @telemetry __MODULE__.MockTelemetry

  describe "submit/1" do
    test "emits a :submit and :submit_success telemetry event on a successful submission" do
      {:ok, _} = Transaction.submit(<<1, 1, 1>>, @child_chain, @telemetry)

      assert_receive({:telemetry_emitted, [:submit, Transaction]})
      assert_receive({:telemetry_emitted, [:submit_success, Transaction]})
    end

    test "emits a :submit and :submit_failed telemetry event on a failed submission" do
      {:error, _} = Transaction.submit(<<0, 0, 0>>, @child_chain, @telemetry)

      assert_receive({:telemetry_emitted, [:submit, Transaction]})
      assert_receive({:telemetry_emitted, [:submit_failed, Transaction]})
    end
  end

  defmodule MockChildChain do
    @doc """
    Returns a successful or failed response depending on the txbyte received.
    """
    def submit(<<1, 1, 1>>), do: {:ok, %{some: "data"}}
    def submit(<<0, 0, 0>>), do: {:error, :some_error}
  end

  defmodule MockTelemetry do
    @doc """
    Responds to an execute/2 call by sending `{:telemtry_emitted, _}` to the mailbox.
    """
    def execute(event, _) do
      send(self(), {:telemetry_emitted, event})
      :ok
    end
  end
end
