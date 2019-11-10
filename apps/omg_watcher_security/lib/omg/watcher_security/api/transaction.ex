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

defmodule OMG.WatcherSecurity.API.Transaction do
  @moduledoc """
  Module provides API for transactions
  """

  alias OMG.State.Transaction

  alias OMG.Utxo

  alias OMG.WatcherSecurity.HttpRPC.Client

  require Utxo

  @doc """
  Passes signed transaction to the child chain only if it's secure, e.g.
  * Watcher is fully synced,
  * all operator blocks have been verified,
  * transaction doesn't spend funds not yet mined
  * etc...
  """
  @spec submit(Transaction.Signed.t()) :: Client.response_t() | {:error, atom()}
  def submit(%Transaction.Signed{} = signed_tx) do
    url = Application.get_env(:omg_watcher_security, :child_chain_url)

    signed_tx
    |> Transaction.Signed.encode()
    |> Client.submit(url)
  end
end
