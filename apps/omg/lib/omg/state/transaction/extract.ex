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

defmodule OMG.State.Transaction.Extract do
  @moduledoc """
    Helpers for extracting specific data from Transaction type structs.
  """
  alias OMG.Crypto
  alias OMG.State.Transaction.Protocol
  alias OMG.State.Transaction.Recovered
  alias OMG.State.Transaction.Signed

  @type any_flavor_t() :: Signed.t() | Recovered.t() | Protocol.t()
  @type tx_hash() :: Crypto.hash_t()
  @doc """
  Returns all inputs, never returns zero inputs
  """
  @spec get_inputs(any_flavor_t()) :: list()
  def get_inputs(%Recovered{signed_tx: signed_tx}), do: get_inputs(signed_tx)
  def get_inputs(%Signed{raw_tx: raw_tx}), do: get_inputs(raw_tx)
  def get_inputs(tx), do: Protocol.get_inputs(tx)

  @doc """
  Returns all outputs, never returns zero outputs
  """
  @spec get_outputs(any_flavor_t()) :: list()
  def get_outputs(%Recovered{signed_tx: signed_tx}), do: get_outputs(signed_tx)
  def get_outputs(%Signed{raw_tx: raw_tx}), do: get_outputs(raw_tx)
  def get_outputs(tx), do: Protocol.get_outputs(tx)

  @doc """
  Returns the encoded bytes of the raw transaction involved, i.e. without the signatures
  """
  @spec raw_txbytes(any_flavor_t()) :: binary
  def raw_txbytes(%Recovered{signed_tx: signed_tx}), do: raw_txbytes(signed_tx)
  def raw_txbytes(%Signed{raw_tx: raw_tx}), do: raw_txbytes(raw_tx)
  def raw_txbytes(raw_tx), do: encode(raw_tx)

  @doc """
  Returns the hash of the raw transaction involved, i.e. without the signatures
  """
  @spec raw_txhash(any_flavor_t()) :: tx_hash()
  def raw_txhash(%Recovered{tx_hash: hash}), do: hash
  def raw_txhash(%Signed{raw_tx: raw_tx}), do: raw_txhash(raw_tx)
  def raw_txhash(raw_tx), do: hash(raw_tx)

  defp hash(tx) do
    tx
    |> encode()
    |> Crypto.hash()
  end

  defp encode(transaction) do
    data = Protocol.get_data_for_rlp(transaction)
    ExRLP.encode(data)
  end
end
