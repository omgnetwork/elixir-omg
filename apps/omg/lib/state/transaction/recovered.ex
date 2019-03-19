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

defmodule OMG.State.Transaction.Recovered do
  @moduledoc """
  Representation of a Signed transaction, with addresses recovered from signatures (from `OMG.State.Transaction.Signed`)
  Intent is to allow concurrent processing of signatures outside of serial processing in `OMG.State`
  """

  alias OMG.Crypto
  alias OMG.State.Transaction

  @empty_signature <<0::size(520)>>
  @type tx_hash_t() :: <<_::768>>

  defstruct [:signed_tx, :tx_hash, spenders: nil]

  @type t() :: %__MODULE__{
          tx_hash: tx_hash_t(),
          spenders: [Crypto.address_t()],
          signed_tx: Transaction.Signed.t()
        }

  @spec recover_from(Transaction.Signed.t()) :: {:ok, t()} | any
  def recover_from(%Transaction.Signed{raw_tx: raw_tx, sigs: sigs} = signed_tx) do
    hash_without_sigs = Transaction.hash(raw_tx)

    # TODO: remove unnecessary `encode |> decode`. It's here to allow testing `illegality of gaps in inputs|outputs`
    # on "public API level" while keeping actual check very bottom in `Transaction.decode`.
    # This is expected to be fixed with PR #529
    with {:ok, _} <- raw_tx |> Transaction.encode() |> Transaction.decode(),
         {:ok, spenders} <- get_spenders(hash_without_sigs, sigs),
         do:
           {:ok,
            %__MODULE__{
              tx_hash: Transaction.hash(raw_tx),
              spenders: spenders,
              signed_tx: signed_tx
            }}
  end

  defp get_spenders(hash_without_sigs, sigs) do
    sigs
    |> Enum.filter(fn sig -> sig != @empty_signature end)
    |> Enum.reduce({:ok, []}, fn sig, acc -> get_spender(hash_without_sigs, sig, acc) end)
  end

  defp get_spender(_hash_without_sigs, _sig, {:error, _} = err), do: err

  defp get_spender(hash_without_sigs, sig, {:ok, spenders}) do
    recovered_address = Crypto.recover_address(hash_without_sigs, sig)

    case recovered_address do
      {:ok, spender} -> {:ok, spenders ++ [spender]}
      error -> error
    end
  end

  @doc """
  Checks if input spenders and recovered transaction's spenders are the same and have the same order
  """
  @spec all_spenders_authorized(t(), list()) :: :ok
  def all_spenders_authorized(%__MODULE__{spenders: spenders}, inputs_spenders) do
    if spenders == inputs_spenders, do: :ok, else: {:error, :unauthorized_spent}
  end
end
