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

defmodule OMG.Transaction.Encoding do
  @moduledoc """
  This module contains the public Transaction API to be prefered to access data of different transaction "flavors",
  like `Transaction.Signed` or `OMG.Transaction.Recovered`
  """

  alias OMG.Utxo

  require Utxo

  # TODO: commented code for the tx markers handling
  #
  # @payment_marker Transaction.Markers.payment()
  # @tx_types_modules %{@payment_marker => Transaction.Payment}
  # @type_markers Map.keys(@tx_types_modules)
  #
  # end tx markers section

  @type tx_bytes() :: binary()

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
    protocol_module = Transaction.Payment

    with {:ok, reconstructed} <- protocol_module.reconstruct(raw_tx_rlp_decoded_chunks),
         do: {:ok, reconstructed}
  end

  # TODO: commented code for tx type handling
  # def dispatching_reconstruct(_), do: {:error, :malformed_transaction}
  #
  # end commented section
  @spec decode(tx_bytes()) :: {:ok, Transaction.Protocol.t()} | {:error, decode_error()}
  def decode(tx_bytes) do
    with {:ok, raw_tx_rlp_decoded_chunks} <- try_exrlp_decode(tx_bytes),
         do: dispatching_reconstruct(raw_tx_rlp_decoded_chunks)
  end

  def decode!(tx_bytes) do
    {:ok, tx} = decode(tx_bytes)
    tx
  end

  defp try_exrlp_decode(tx_bytes) do
    {:ok, ExRLP.decode(tx_bytes)}
  rescue
    _ -> {:error, :malformed_transaction_rlp}
  end

  # defp hash(tx) do
  #   tx
  #   |> encode()
  #   |> Crypto.hash()
  # end

  # defp encode(transaction) do
  #   data = Transaction.Protocol.get_data_for_rlp(transaction)
  #   ExRLP.encode(data)
  # end
end
