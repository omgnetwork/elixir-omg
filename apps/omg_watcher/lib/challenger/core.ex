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

  alias OMG.API.Block
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
  @spec create_challenge(Block.t(), Block.t(), Utxo.Position.t()) :: Challenge.t()
  def create_challenge(creating_block, spending_block, utxo_exit) do
    # FIXME: refactor to: get_creating_transaction, get_owner, get_spending_transaction, get_input_index
    {owner, tx} = get_creating_transaction(creating_block, utxo_exit)

    {input_index,
     %Transaction.Signed{
       raw_tx: challenging_tx,
       sigs: sigs,
       signed_tx_bytes: challenging_tx_bytes
     }} = get_spending_transaction(spending_block, utxo_exit)

    %Challenge{
      outputId: Utxo.Position.encode(utxo_exit),
      inputIndex: input_index,
      txbytes: challenging_tx_bytes,
      sig: find_sig(sigs, challenging_tx, owner)
    }
  end

  defp find_sig(sigs, raw_tx, owner) do
    tx_hash = Transaction.hash(raw_tx)

    Enum.find(sigs, fn sig ->
      {:ok, owner} == Crypto.recover_address(tx_hash, sig)
    end)
  end

  @spec get_spending_transaction(Block.t(), Utxo.Position.t()) :: {non_neg_integer, Transaction.Signed.t()} | false
  defp get_spending_transaction(%Block{transactions: txsbytes}, utxo_pos) do
    txsbytes
    |> Enum.map(&Transaction.Signed.decode/1)
    |> Enum.with_index()
    |> Enum.find_value(fn {{:ok, %Transaction.Signed{raw_tx: tx} = tx_signed}, txindex} ->
      inputs = Transaction.get_inputs(tx)

      if input_index = Enum.find_index(inputs, &(&1 == utxo_pos)) do
        {input_index, tx_signed}
      else
        false
      end
    end)
  end

  @spec get_creating_transaction(Block.t(), Utxo.Position.t()) ::
          {Crypto.address_t(), Transaction.t()} | :error | {:error, :malformed_transaction_rlp}
  defp get_creating_transaction(
         %Block{
           transactions: txsbytes,
           number: blknum
         },
         Utxo.position(blknum, txindex, oindex)
       ) do
    with {:ok, txbytes} <- Enum.fetch(txsbytes, txindex),
         {:ok, %Transaction.Signed{raw_tx: tx}} = Transaction.Signed.decode(txbytes),
         outputs <- Transaction.get_outputs(tx),
         {:ok, %{owner: owner}} <- Enum.fetch(outputs, oindex) do
      {owner, tx}
    end
  end
end
