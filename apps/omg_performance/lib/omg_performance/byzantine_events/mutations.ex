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

defmodule OMG.Performance.ByzantineEvents.Mutations do
  @moduledoc """
  Provides helper functions mutate existing entities, preparing them to be used by performance testing routines, for
  example creating double-spending transactions from healthy transactions
  """

  alias OMG.Crypto
  alias OMG.DevCrypto
  alias OMG.State.Transaction

  @doc """
  Mutates an Enumerable of signed, encoded transactions, by modifying the metadata field
  """
  def mutate_txs(txs, signers_priv_keys) do
    txs
    |> Enum.map(&Transaction.Signed.decode!/1)
    |> Enum.map(&mutate_raw_tx(&1.raw_tx))
    |> Enum.map(&DevCrypto.sign(&1, signers_priv_keys))
    |> Enum.map(&Transaction.Signed.encode/1)
  end

  # just put as metadata something different from the current metadata
  defp mutate_raw_tx(%{metadata: old_metadata} = raw_tx),
    do: %{raw_tx | metadata: Crypto.hash(old_metadata)}
end
