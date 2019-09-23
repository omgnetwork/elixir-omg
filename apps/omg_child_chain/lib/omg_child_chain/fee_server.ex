# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.ChildChain.FeeServer do
  @moduledoc """
  Maintains current fee rates and tokens in which fees may be paid.
  Periodically updates fees information from external source (file in omg_child_chain/priv config :omg_child_chain,
  :fee_specs_file_name) until switched off with config :omg_child_chain, :ignore_fees.

  Fee's file parsing and rules of transaction's fee validation are in `OMG.Fees`
  """

  alias OMG.ChildChain.FeeParser
  alias OMG.Fees
  alias OMG.Status.Alert.Alarm

  use GenServer
  use OMG.Utils.LoggerExt

  @fee_file_check_interval_ms Application.fetch_env!(:omg_child_chain, :fee_file_check_interval_ms)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(args) do
    :ok = ensure_ets_init()

    args =
      case Application.get_env(:omg_child_chain, :ignore_fees) do
        true ->
          :ok = save_fees(:no_fees_transaction, 0)
          _ = Logger.warn("Fee specs from file are ignored.")
          args

        opt when is_nil(opt) or is_boolean(opt) ->
          :ok = update_fee_spec()
          interval = Keyword.get(args, :interval_ms, @fee_file_check_interval_ms)
          {:ok, tref} = :timer.send_interval(interval, self(), :update_fee_spec)
          Keyword.put(args, :tref, tref)
      end

    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:ok, args}
  end

  @doc """
  Returns accepted tokens and amounts in which transaction fees are collected
  """
  @spec transaction_fees() :: {:ok, Fees.fee_t()}
  def transaction_fees do
    {:ok, load_fees()}
  end

  def handle_info(:update_fee_spec, state) do
    _ =
      if Application.get_env(:omg_child_chain, :ignore_fees) do
        _ = Logger.warn("Fee specs from file are ignored. Updates takes no effect.")
      else
        alarm = {:invalid_fee_file, Node.self(), __MODULE__}

        case update_fee_spec() do
          :ok ->
            Alarm.clear(alarm)

          _ ->
            Alarm.set(alarm)
        end
      end

    {:noreply, state}
  end

  # Reads fee specification file if needed and updates :ets state with current fees information
  # FeeServer is an internal elixir process* that holds child chain's fees per currency.
  # The operator can change the fees and this is done via a JSON file that iss loaded from disk (path variable).
  # sobelow_skip ["Traversal"]
  @spec update_fee_spec() :: :ok | {:error, atom() | [{:error, atom()}, ...]}
  defp update_fee_spec do
    path = get_fees()

    with {:reload, changed_at} <- should_load_file(path),
         {:ok, content} <- File.read(path),
         {:ok, specs} <- FeeParser.parse_file_content(content) do
      :ok = save_fees(specs, changed_at)
      _ = Logger.info("Reloaded #{inspect(Enum.count(specs))} fee specs from file, changed at #{inspect(changed_at)}")
      :ok
    else
      {:file_unchanged, _last_change_at} ->
        :ok

      error ->
        _ = Logger.error("Unable to update fees from file. Reason: #{inspect(error)}")
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

  defp get_fees,
    do: "#{:code.priv_dir(:omg_child_chain)}/#{Application.get_env(:omg_child_chain, :fee_specs_file_name)}"
end
