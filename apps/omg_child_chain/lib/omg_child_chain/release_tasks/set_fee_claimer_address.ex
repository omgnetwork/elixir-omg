# Copyright 2019-2019 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.ReleaseTasks.SetFeeClaimerAddress do
  @moduledoc false
  use Distillery.Releases.Config.Provider
  require Logger

  # NOTE: `omg` is correct configuration scope for this value. However setting it via `Release Task`
  # is specific to Child-chain app. Watcher can go with defaults.
  @app :omg

  @default_fee_claimer_address "DEAD000000000000000000000000000000000000"
  @zero_address <<0::160>>

  @impl Provider
  def init(_args) do
    _ = Application.ensure_all_started(:logger)

    fee_claimer_address = get_fee_claimer_address()
    Application.put_env(@app, :fee_claimer_address, fee_claimer_address, persistent: true)

    :ok
  end

  defp get_fee_claimer_address do
    address =
      "FEE_CLAIMER_ADDRESS"
      |> System.get_env()
      |> validate_address(@default_fee_claimer_address)

    _ = Logger.info("CONFIGURATION: App: #{@app} Key: FEE_CLAIMER_ADDRESS Value: #{inspect(address)}.")

    address
  end

  defp validate_address("0x" <> value, default), do: validate_address(value, default)

  defp validate_address(value, _default) when is_binary(value) do
    with {:ok, address} when byte_size(address) == 20 and address != @zero_address <-
           value |> String.upcase() |> Base.decode16() do
      address
    else
      :error -> exit("Fee claimer address has to be HEX-encoded string")
      {:ok, @zero_address} -> exit("Fee claimer address cannot be zero-bytes")
      _ -> exit("Fee claimer address has to be 20-bytes long")
    end
  end

  defp validate_address(_, default), do: Base.decode16!(default)
end
