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

defmodule OMG.Watcher.Challenger.Core do
  @moduledoc """
  Functional core of challenger
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.Challenger.Challenge
  alias OMG.Watcher.DB

  @doc """
  Creates a challenge for exiting utxo. Data is prepared that transaction contains only one input
  which is UTXO being challenged.
  More: [contract's challengeExit](https://github.com/omisego/plasma-contracts/blob/22936d561a036d49aa6a215531e70c5779df058f/contracts/RootChain.sol#L244)
  """
  @spec create_challenge(%DB.Transaction{}, Utxo.Position.t()) :: Challenge.t()
  def create_challenge(challenging_tx, utxo_exit) do
    {:ok,
     %Transaction.Signed{
       raw_tx: raw_tx,
       sigs: sigs
     }} = Transaction.Signed.decode(challenging_tx.txbytes)

    owner = get_eutxo_owner(challenging_tx)

    %Challenge{
      outputId: Utxo.Position.encode(utxo_exit),
      # eUtxoIndex - The output position of the exiting utxo.
      inputIndex: get_eutxo_index(challenging_tx),
      txbytes: Transaction.encode(raw_tx),
      sig: find_sig(sigs, raw_tx, owner)
    }
  end

  defp find_sig(sigs, raw_tx, owner) do
    hash_no_spenders = Transaction.hash(raw_tx)

    Enum.find(sigs, fn sig ->
      {:ok, owner} == Crypto.recover_address(hash_no_spenders, sig)
    end)
  end

  # here: challenging_tx is prepared to contain just utxo_exit input only,
  # see: DB.Transaction.get_transaction_challenging_utxo/1
  defp get_eutxo_index(%DB.Transaction{inputs: [input]}),
    do: input.spending_tx_oindex

  defp get_eutxo_owner(%DB.Transaction{inputs: [input]}),
    do: input.owner
end
