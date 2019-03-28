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

defmodule OMG.Watcher.ExitProcessor.Tools do
  @moduledoc """
  Functional common tools useful when processing transactions to be used as challenges.

  NOTE: unit tested by means of more public API calls like `OMG.Watcher.Challenger` or `OMG.Watcher.ExitProcessor`
  """

  alias OMG.Crypto
  alias OMG.State.Transaction

  @doc """
  Finds the exact signature which signed the particular transaction for the given owner address
  """
  @spec find_sig(Transaction.Signed.t(), Crypto.address_t()) :: {:ok, Crypto.sig_t()} | nil
  def find_sig(%Transaction.Signed{raw_tx: tx, sigs: sigs}, owner) do
    tx_hash = Transaction.hash(tx)

    Enum.find(sigs, fn sig ->
      {:ok, owner} == Crypto.recover_address(tx_hash, sig)
    end)
    |> case do
      nil -> nil
      other -> {:ok, other}
    end
  end
end
