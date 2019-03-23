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

defmodule OMG.State.Transaction.Signed do
  @moduledoc """
  Representation of a signed transaction
  """

  alias OMG.Crypto
  alias OMG.State.Transaction

  @signature_length 65
  @type tx_bytes() :: binary() | nil

  defstruct [:raw_tx, :sigs, :signed_tx_bytes]

  @type t() :: %__MODULE__{
          raw_tx: Transaction.t(),
          sigs: [Crypto.sig_t()],
          signed_tx_bytes: tx_bytes()
        }

  def encode(%__MODULE__{
        raw_tx: raw_tx,
        sigs: sigs
      }) do
    [sigs | Transaction.get_data_for_rlp(raw_tx)]
    |> ExRLP.encode()
  end

  def decode(signed_tx_bytes) do
    with {:ok, raw_tx_rlp_decoded_chunks} <- try_exrlp_decode(signed_tx_bytes),
         do: reconstruct(raw_tx_rlp_decoded_chunks, signed_tx_bytes)
  end

  defp try_exrlp_decode(signed_tx_bytes) do
    {:ok, ExRLP.decode(signed_tx_bytes)}
  rescue
    _ -> {:error, :malformed_transaction_rlp}
  end

  defp reconstruct([sigs | raw_tx_rlp_decoded_chunks], signed_tx_bytes) do
    with true <- is_list(sigs),
         true <- Enum.all?(sigs, &signature_length?/1),
         {:ok, raw_tx} <- Transaction.reconstruct(raw_tx_rlp_decoded_chunks) do
      {:ok,
       %__MODULE__{
         raw_tx: raw_tx,
         sigs: sigs,
         signed_tx_bytes: signed_tx_bytes
       }}
    else
      false -> {:error, :malformed_signatures}
      err -> err
    end
  end

  defp reconstruct(_, _), do: {:error, :malformed_transaction}

  defp signature_length?(sig) when byte_size(sig) == @signature_length, do: true
  defp signature_length?(_sig), do: false
end
