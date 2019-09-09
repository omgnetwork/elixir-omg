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

defmodule OMG.State.Transaction.Decode do
  @moduledoc """
  This module contains the transaction API related to RLP decoding
  and matching with appropriate dispatching module??? Shouldn't be here.
  """

  alias OMG.Crypto
  alias OMG.Transaction.Protocol
  alias OMG.Utxo
  require Utxo

  # TODO: commented code for the tx markers handling
  #
  # @payment_marker Transaction.Markers.payment()
  # @tx_types_modules %{@payment_marker => Transaction.Payment}
  # @type_markers Map.keys(@tx_types_modules)
  #
  # end tx markers section

  @type any_flavor_t() :: __MODULE__.Signed.t() | __MODULE__.Recovered.t() | __MODULE__.Protocol.t()

  @type tx_bytes() :: binary()
  @type tx_hash() :: Crypto.hash_t()
  @type metadata() :: binary() | nil

  @type decode_error() ::
          :malformed_transaction_rlp
          | :malformed_inputs
          | :malformed_outputs
          | :malformed_address
          | :malformed_metadata
          | :malformed_transaction

  @type input_index_t() :: 0..3

  # TODO: commented code is for the tx type handling
  # def dispatching_reconstruct([type_marker | raw_tx_rlp_decoded_chunks]) when type_marker in @type_markers do
  def dispatching_reconstruct(raw_tx_rlp_decoded_chunks) do
    # protocol_module = @tx_types_modules[type_marker]
    protocol_module = OMG.State.Transaction.Payment

    with {:ok, reconstructed} <- protocol_module.reconstruct(raw_tx_rlp_decoded_chunks),
         do: {:ok, reconstructed}
  end

  # TODO: commented code for tx type handling
  # def dispatching_reconstruct(_), do: {:error, :malformed_transaction}
  #
  # end commented section
  @spec it(tx_bytes()) :: {:ok, Protocol.t()} | {:error, decode_error()}
  def it(tx_bytes), do: decode(tx_bytes)

  def it!(tx_bytes) do
    {:ok, tx} = decode(tx_bytes)
    tx
  end

  defp decode(tx_bytes) do
    with {:ok, raw_tx_rlp_decoded_chunks} <- try_exrlp_decode(tx_bytes),
         do: dispatching_reconstruct(raw_tx_rlp_decoded_chunks)
  end

  defp try_exrlp_decode(tx_bytes) do
    {:ok, ExRLP.decode(tx_bytes)}
  rescue
    _ -> {:error, :malformed_transaction_rlp}
  end
end
