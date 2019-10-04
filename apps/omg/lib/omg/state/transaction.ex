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

defmodule OMG.State.Transaction do
  @moduledoc """
  This module contains the public Transaction API to be prefered to access data of different transaction "flavors",
  like `Transaction.Signed` or `Transaction.Recovered`
  """

  alias OMG.Crypto
  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo

  @tx_types_modules Application.fetch_env!(:omg, :tx_types_modules)
  @type_markers Map.keys(@tx_types_modules)

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

  defmacro is_metadata(metadata) do
    quote do
      is_binary(unquote(metadata)) and byte_size(unquote(metadata)) == 32
    end
  end

  @type input_index_t() :: 0..3

  def dispatching_reconstruct([type_marker | raw_tx_rlp_decoded_chunks]) when type_marker in @type_markers do
    protocol_module = @tx_types_modules[type_marker]
    protocol_module.reconstruct(raw_tx_rlp_decoded_chunks)
  end

  def dispatching_reconstruct(_), do: {:error, :malformed_transaction}

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

  defp encode(transaction) do
    Transaction.Protocol.get_data_for_rlp(transaction)
    |> ExRLP.encode()
  end

  defp hash(tx) do
    tx
    |> encode()
    |> Crypto.hash()
  end

  @doc """
  Returns all inputs, never returns zero inputs
  """
  @spec get_inputs(any_flavor_t()) :: list()
  def get_inputs(%__MODULE__.Recovered{signed_tx: signed_tx}), do: get_inputs(signed_tx)
  def get_inputs(%__MODULE__.Signed{raw_tx: raw_tx}), do: get_inputs(raw_tx)
  def get_inputs(tx), do: Transaction.Protocol.get_inputs(tx)

  @doc """
  Returns all outputs, never returns zero outputs
  """
  @spec get_outputs(any_flavor_t()) :: list()
  def get_outputs(%__MODULE__.Recovered{signed_tx: signed_tx}), do: get_outputs(signed_tx)
  def get_outputs(%__MODULE__.Signed{raw_tx: raw_tx}), do: get_outputs(raw_tx)
  def get_outputs(tx), do: Transaction.Protocol.get_outputs(tx)

  @doc """
  Returns the encoded bytes of the raw transaction involved, i.e. without the signatures
  """
  @spec raw_txbytes(any_flavor_t()) :: binary
  def raw_txbytes(%__MODULE__.Recovered{signed_tx: signed_tx}), do: raw_txbytes(signed_tx)
  def raw_txbytes(%__MODULE__.Signed{raw_tx: raw_tx}), do: raw_txbytes(raw_tx)
  def raw_txbytes(raw_tx), do: encode(raw_tx)

  @doc """
  Returns the hash of the raw transaction involved, i.e. without the signatures
  """
  @spec raw_txhash(any_flavor_t()) :: tx_hash()
  def raw_txhash(%__MODULE__.Recovered{tx_hash: hash}), do: hash
  def raw_txhash(%__MODULE__.Signed{raw_tx: raw_tx}), do: raw_txhash(raw_tx)
  def raw_txhash(raw_tx), do: hash(raw_tx)
end

defprotocol OMG.State.Transaction.Protocol do
  @moduledoc """
  Should be implemented for any type of transaction processed in the system
  """

  alias OMG.InputPointer
  alias OMG.Output
  alias OMG.State.Transaction

  @doc """
  Transforms structured data into RLP-structured (encodable) list of fields
  """
  @spec get_data_for_rlp(t()) :: list(any())
  def get_data_for_rlp(tx)

  @doc """
  List of input pointers (e.g. of which one implementation is `utxo_pos`) this transaction is intending to spend
  """
  @spec get_inputs(t()) :: list(InputPointer.Protocol.t())
  def get_inputs(tx)

  @doc """
  List of outputs this transaction intends to create
  """
  @spec get_outputs(t()) :: list(Output.Protocol.t())
  def get_outputs(tx)

  @doc """
  Custom validation of the transaction with respect to its witnesses. Part of stateless validation routine
  """
  @spec valid?(t(), Transaction.Signed.t()) :: true | {:error, atom}
  def valid?(tx, signed_tx)

  @doc """
  Custom stateful validity, based on pre-fetched subset of input UTXOs

  Should also return the fees that this transaction is paying, mapped by currency; for fee validation
  """
  @spec can_apply?(t(), Output.Protocol.t()) :: {:ok, map()} | {:error, atom}
  def can_apply?(tx, input_utxos)
end
