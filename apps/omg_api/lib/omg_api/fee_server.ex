# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.FeeServer do
  @moduledoc """
  Maintains current fee rates and acceptable tokens.
  Updates fees information from external source.
  Provides function to validate transaction's fee.
  """

  alias OMG.Fees

  use GenServer
  use OMG.LoggerExt

  @file_changed_check_interval_ms 10_000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(args) do
    :ok = ensure_ets_init()

    _ =
      case Application.get_env(:omg_api, :ignore_fees) do
        true ->
          :ok = save_fees(:ignore, 0)
          _ = Logger.info("fee specs from file is ignore")

        opt when is_nil(opt) or is_boolean(opt) ->
          :ok = update_fee_spec()
          {:ok, _} = :timer.apply_interval(@file_changed_check_interval_ms, __MODULE__, :update_fee_spec, [])
      end

    _ = Logger.info("Started FeeServer")
    {:ok, args}
  end

  @doc """
  Returns accepted tokens and amounts in which transaction fees are collected
  """
  @spec transaction_fees() :: {:ok, Fees.fee_t()}
  def transaction_fees do
    {:ok, load_fees()}
  end

  @doc """
   Reads fee specification file if needed and updates :ets state with current fees information
  """
  @spec update_fee_spec() :: :ok
  def update_fee_spec do
    path = Application.fetch_env!(:omg_api, :fee_specs_file_path)

    :ok =
      with {:reload, changed_at} <- should_load_file(path),
           {:ok, content} <- File.read(path),
           {:ok, specs} <- Fees.parse_file_content(content) do
        :ok = save_fees(specs, changed_at)
        _ = Logger.info("Reloaded #{inspect(Enum.count(specs))} fee specs from file, changed at #{inspect(changed_at)}")

        :ok
      else
        {:file_unchanged, _last_change_at} ->
          :ok

        {:error, :enoent} ->
          _ = Logger.error("The fee specification file #{inspect(path)} not found in #{System.get_env("PWD")}")

          {:error, :fee_spec_not_found}

        error ->
          _ = Logger.warn("Unable to update fees from file. Reason: #{inspect(error)}")
          error
      end
  end

  defp save_fees(fee_specs, loaded_at) do
    true = :ets.insert(:fees_bucket, [{:last_loaded, loaded_at}, {:fees, fee_specs}])
    :ok
  end

  defp load_fees, do: :ets.lookup_element(:fees_bucket, :fees, 2)

  defp should_load_file(path) do
    loaded = get_last_loaded_file_timestamp()
    changed = get_file_last_modified_timestamp(path)

    if changed > loaded,
      do: {:reload, changed},
      else: {:file_unchanged, loaded}
  end

  defp get_last_loaded_file_timestamp do
    [{:last_loaded, timestamp}] = :ets.lookup(:fees_bucket, :last_loaded)
    # When not matched we prefer immediate crash here as this should never happened

    timestamp
  end

  defp get_file_last_modified_timestamp(path) do
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{mtime: mtime}} ->
        mtime

      # possibly wrong path - returns current timestamp to force file reload where file errors are handled
      _ ->
        :os.system_time(:second)
    end
  end

  defp ensure_ets_init do
    _ = if :undefined == :ets.info(:fees_bucket), do: :ets.new(:fees_bucket, [:set, :public, :named_table])

    true = :ets.insert(:fees_bucket, {:last_loaded, 0})
    :ok
  end
end
