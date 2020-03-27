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

defmodule OMG.ChildChain.Fees.FileAdapter do
  @moduledoc """
  Adapter for fees stored in a JSON file (defined in omg_child_chain/priv config :omg_child_chain,
  fee_adapter_opts: `specs_file_name` keyword opts).
  """
  @behaviour OMG.ChildChain.Fees.Adapter

  use OMG.Utils.LoggerExt

  alias OMG.ChildChain.Fees.JSONFeeParser

  @doc """
  Reads fee specification file if needed and returns its content.
  When using this adapter, the operator can change the fees by updating a
  JSON file that is loaded from disk (path variable).
  """
  # sobelow_skip ["Traversal"]
  @impl true
  def get_fee_specs(opts, _actual_fee_specs, recorded_file_updated_at) do
    path = get_path(opts)

    with {:changed, file_updated_at} <- check_file_changes(path, recorded_file_updated_at),
         {:ok, content} <- File.read(path),
         {:ok, fee_specs} <- JSONFeeParser.parse(content) do
      {:ok, fee_specs, file_updated_at}
    else
      {:unchanged, _last_changed_at} ->
        :ok

      error ->
        error
    end
  end

  defp check_file_changes(path, recorded_file_updated_at) do
    actual_file_updated_at = get_file_last_modified_timestamp(path)

    case actual_file_updated_at > recorded_file_updated_at do
      true ->
        {:changed, actual_file_updated_at}

      false ->
        {:unchanged, recorded_file_updated_at}
    end
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

  defp get_path(opts) do
    "#{:code.priv_dir(:omg_child_chain)}/#{Keyword.fetch!(opts, :specs_file_name)}"
  end
end
