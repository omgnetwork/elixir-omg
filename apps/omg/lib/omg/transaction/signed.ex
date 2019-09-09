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

defmodule OMG.Transaction.Signed do
  @moduledoc """
  Representation of a signed transaction.

  NOTE: before you use this, make sure you shouldn't use `Transaction` or `OMG.Transaction.Recovered`
  """

  alias OMG.Crypto
  alias OMG.Transaction
  alias OMG.Transaction.Witness
  alias OMG.TypedDataHash
  alias OMG.Transaction.Decoding
  alias OMG.Transaction.Signed

  @type tx_bytes() :: binary()
  @empty_signature <<0::size(520)>>

  defstruct [:raw_tx, :sigs]

  @type t() :: %__MODULE__{
          raw_tx: Transaction.Protocol.t(),
          sigs: [Crypto.sig_t()]
        }

  @doc """
  Produce a binary form of a signed transaction - coerces into RLP-encodeable structure and RLP encodes
  """
  @spec encode(t()) :: tx_bytes()
  def encode(%__MODULE__{raw_tx: %{} = raw_tx, sigs: sigs}) do
    [sigs | Transaction.Protocol.get_data_for_rlp(raw_tx)]
    |> ExRLP.encode()
  end

  @doc """
  Produces a struct from the binary encoded form of a signed transactions - RLP decodes to structure of RLP-items
  and then produces an Elixir struct
  """
  @spec decode(tx_bytes()) :: {:ok, t()} | {:error, atom}
  def decode(signed_tx_bytes) do
    with {:ok, tx_rlp_decoded_chunks} <- generic_decode(signed_tx_bytes),
         do: reconstruct(tx_rlp_decoded_chunks)
  end

  @doc """
  See `decode/1`
  """
  @spec decode!(tx_bytes()) :: t()
  def decode!(signed_tx_bytes) do
    {:ok, decoded} = decode(signed_tx_bytes)
    decoded
  end

  @doc """
  Recovers the witnesses for non-empty signatures, in the order they appear in transaction's signatures
  """
  @spec get_witnesses(Transaction.Signed.t()) :: {:ok, list(Crypto.address_t())} | {:error, atom}
  def get_witnesses(%Transaction.Signed{raw_tx: raw_tx, sigs: raw_witnesses}) do
    raw_txhash = TypedDataHash.hash_struct(raw_tx)

    with {:ok, reversed_witnesses} <- get_reversed_witnesses(raw_txhash, raw_tx, raw_witnesses),
         do:
           {:ok,
            reversed_witnesses
            |> Enum.reverse()
            |> Enum.with_index()
            |> Enum.into(%{}, fn {witness, idx} -> {idx, witness} end)}
  end

  def reconstruct([raw_witnesses | typed_tx_rlp_decoded_chunks]) do
    with true <- is_list(raw_witnesses) || {:error, :malformed_witnesses},
         true <- Enum.all?(raw_witnesses, &Witness.valid?/1) || {:error, :malformed_witnesses},
         {:ok, raw_tx} <- Decoding.dispatching_reconstruct(typed_tx_rlp_decoded_chunks),
         do: {:ok, %Signed{raw_tx: raw_tx, sigs: raw_witnesses}}
  end

  def reconstruct(_), do: {:error, :malformed_transaction}

  defp get_reversed_witnesses(raw_txhash, raw_tx, raw_witnesses) do
    raw_witnesses
    # TODO: move this check out of here and make generic?
    #       (or remove altogether - this covers the padding using empty signatures, which might be going away)
    |> Enum.filter(fn raw_witness -> raw_witness != @empty_signature end)
    |> Enum.reduce_while({:ok, []}, fn raw_witness, acc -> get_witness(raw_txhash, raw_tx, raw_witness, acc) end)
  end

  defp get_witness(raw_txhash, raw_tx, raw_witness, {:ok, witnesses}) do
    Witness.recover(raw_witness, raw_txhash, raw_tx)
    |> case do
      {:ok, witness} -> {:cont, {:ok, [witness | witnesses]}}
      error -> {:halt, error}
    end
  end

  defp generic_decode(signed_tx_bytes) do
    {:ok, ExRLP.decode(signed_tx_bytes)}
  rescue
    _ -> {:error, :malformed_transaction_rlp}
  end
end
