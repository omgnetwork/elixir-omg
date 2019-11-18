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

defmodule OMG.Performance.ByzantineEvents.TransactionCreator do
  @moduledoc """
  Helper module which wraps all things necessary to easily create and sign transactions to use when perftesting
  """

  alias OMG.DevCrypto
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @eth OMG.Eth.RootChain.eth_pseudo_address()

  @doc """
  Provided a utxo position, produce any spending transaction
  """
  def spend_utxo_by(Utxo.position(blknum, txindex, oindex), recipient_address, sender_priv_key, amount) do
    Transaction.Payment.new([{blknum, txindex, oindex}], [{recipient_address, @eth, amount}])
    |> DevCrypto.sign([sender_priv_key])
    |> Transaction.Signed.encode()
  end

  def spend_utxo_by(encoded_utxo_pos, recipient_address, sender_priv_key, amount),
    do: spend_utxo_by(Utxo.Position.decode!(encoded_utxo_pos), recipient_address, sender_priv_key, amount)
end
