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
  alias __MODULE__.MockChildChain

  setup do
    handler_id = {__MODULE__, :rand.uniform(100)}

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    {:ok, handler_id: handler_id}
  end

  describe "submit/1 with a successful result" do
    test "emits a [:submit, ...] telemetry event", context do
      attach(context.handler_id, [:submit, Transaction])
      {:ok, _} = Transaction.submit(<<1, 1, 1>>, MockChildChain)
      assert_received({:telemetry_event, [:submit, Transaction], %{}, %{}})
    end

    test "emits a [:submit_success, ...] telemetry event", context do
      attach(context.handler_id, [:submit_success, Transaction])
      {:ok, _} = Transaction.submit(<<1, 1, 1>>, MockChildChain)
      assert_received({:telemetry_event, [:submit_success, Transaction], %{}, %{}})
    end

    test "does not emit a [:submit_failed, ...] telemetry event", context do
      attach(context.handler_id, [:submit_failed, Transaction])
      {:ok, _} = Transaction.submit(<<1, 1, 1>>, MockChildChain)
      refute_received({:telemetry_event, [:submit_failed, Transaction], %{}, %{}})
    end
  end

  describe "submit/1 with a failed result" do
    test "emits a [:submit, ...] telemetry event", context do
      attach(context.handler_id, [:submit, Transaction])
      {:error, _} = Transaction.submit(<<0, 0, 0>>, MockChildChain)
      assert_received({:telemetry_event, [:submit, Transaction], %{}, %{}})
    end

    test "emits a [:submit_failed, ...] telemetry event", context do
      attach(context.handler_id, [:submit_failed, Transaction])
      {:error, _} = Transaction.submit(<<0, 0, 0>>, MockChildChain)
      assert_received({:telemetry_event, [:submit_failed, Transaction], %{}, %{}})
    end

    test "does not emit a [:submit_success, ...] telemetry event", context do
      attach(context.handler_id, [:submit_success, Transaction])
      {:error, _} = Transaction.submit(<<0, 0, 0>>, MockChildChain)
      refute_received({:telemetry_event, [:submit_success, Transaction], %{}, %{}})
    end
  end

  defmodule MockChildChain do
    @doc """
    Returns a successful or failed response depending on the txbytes received.
    """
    def submit(<<1, 1, 1>>), do: {:ok, %{some: "data"}}
    def submit(<<0, 0, 0>>), do: {:error, :some_error}
  end

  defp attach(handler_id, event) do
    :telemetry.attach(
      handler_id,
      event,
      fn received_event, measurements, metadata, _ ->
        send(self(), {:telemetry_event, received_event, measurements, metadata})
      end,
      nil
    )
  end
end
