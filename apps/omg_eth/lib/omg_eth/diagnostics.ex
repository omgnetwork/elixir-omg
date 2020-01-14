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

defmodule OMG.Eth.Diagnostics do
  @moduledoc """
  Facilities to get various diagnostics related to the interactions with the Ethereum node
  """

  @doc """
  Gets an excerpt of the application's configuration describing which child chain (contract address etc.) are we
  talking to
  """
  def get_child_chain_config() do
    config = Application.get_all_env(:omg_eth)
    Keyword.take(config, [:contract_addr, :authority_addr, :txhash_contract])
  end

  @doc """
  Returns a map of responses to basic queries that help to figure out, what node are we talking to.

  Designed so that it never throws, so is safe to use in error recovery code, logging etc.
  """
  def get_node_diagnostics() do
    Enum.into(["personal_listWallets", "admin_nodeInfo", "parity_enode"], %{}, &get_node_diagnostic/1)
  end

  defp get_node_diagnostic(rpc_call_name) when is_binary(rpc_call_name) do
    {rpc_call_name, Ethereumex.HttpClient.request(rpc_call_name, [], [])}
  rescue
    error -> {rpc_call_name, inspect(error)}
  end
end
