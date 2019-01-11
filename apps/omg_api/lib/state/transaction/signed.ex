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

defmodule OMG.API.State.Transaction.Signed do
  @moduledoc """
  Representation of a signed transaction
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction

  @signature_length 65
  @type signed_tx_bytes_t() :: bitstring() | nil

  defstruct [:raw_tx, :sigs, :signed_tx_bytes]

  @type t() :: %__MODULE__{
          raw_tx: Transaction.t(),
          sigs: [Crypto.sig_t()],
          signed_tx_bytes: signed_tx_bytes_t()
        }

  def encode(%__MODULE__{
        raw_tx: raw_tx,
        sigs: sigs
      }) do
    [sigs | Transaction.prepare_to_exrlp(raw_tx)]
    |> ExRLP.encode()
  end

  def decode(signed_tx_bytes) do
    with {:ok, tx} <- try_exrlp_decode(signed_tx_bytes),
         do: reconstruct_tx(tx, signed_tx_bytes)
  end

  defp try_exrlp_decode(signed_tx_bytes) do
    try do
      {:ok, ExRLP.decode(signed_tx_bytes)}
    rescue
      _ -> {:error, :malformed_transaction_rlp}
    end
  end

  defp reconstruct_tx([sigs | raw_tx_rlp], signed_tx_bytes) do
    with true <- Enum.all?(sigs, &signature_length?/1),
         {:ok, raw_tx} <- Transaction.from_rlp(raw_tx_rlp) do
      {:ok,
       %__MODULE__{
         raw_tx: raw_tx,
         sigs: sigs,
         signed_tx_bytes: signed_tx_bytes
       }}
    else
      false -> {:error, :bad_signature_length}
      err -> err
    end
  end

  defp reconstruct_tx(_, _), do: {:error, :malformed_transaction}

  defp signature_length?(sig) when byte_size(sig) == @signature_length, do: true
  defp signature_length?(_sig), do: false
end
