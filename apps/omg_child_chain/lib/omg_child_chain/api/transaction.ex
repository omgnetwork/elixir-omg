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

defmodule OMG.ChildChain.API.Transaction do
  @moduledoc """
  Child Chain API for submitting transactions. This module performs the necessary operations
  on the transaction submission that are not strictly part of the core submission logic.
  """
  alias OMG.ChildChain

  @spec submit(binary()) :: ChildChain.submit_result()
  def submit(txbytes, child_chain \\ ChildChain) do
    :ok = :telemetry.execute([:submit, __MODULE__], %{})

    result = child_chain.submit(txbytes)
    _ = send_telemetry(result)

    result
  end

  defp send_telemetry({:ok, _}) do
    :ok = :telemetry.execute([:submit_success, __MODULE__], %{})
  end

  defp send_telemetry({:error, _}) do
    :ok = :telemetry.execute([:submit_failed, __MODULE__], %{})
  end
end
