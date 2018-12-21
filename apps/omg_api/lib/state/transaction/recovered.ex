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

defmodule OMG.API.State.Transaction.Recovered do
  @moduledoc """
  Representation of a Signed transaction, with addresses recovered from signatures (from `OMG.API.State.Transaction.Signed`)
  Intent is to allow concurent processing of signatures outside of serial processing in `OMG.API.State`
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction

  @empty_signature <<0::size(520)>>
  @type signed_tx_hash_t() :: <<_::768>>

  defstruct [:signed_tx, :signed_tx_hash, spenders: nil]

  @type t() :: %__MODULE__{
          signed_tx_hash: signed_tx_hash_t(),
          spenders: [Crypto.address_t()],
          signed_tx: Transaction.Signed.t()
        }

  @spec recover_from(Transaction.Signed.t()) :: {:ok, t()} | any
  def recover_from(%Transaction.Signed{raw_tx: raw_tx, sigs: sigs} = signed_tx) do
    hash_no_spenders = Transaction.hash(raw_tx)

    with {:ok, spenders} <- get_spenders(hash_no_spenders, sigs),
         do:
           {:ok,
            %__MODULE__{
              signed_tx_hash: Transaction.hash(raw_tx),
              spenders: spenders,
              signed_tx: signed_tx
            }}
  end

  defp get_spenders(hash_no_spenders, sigs) do
    sigs
    |> Enum.filter(fn sig -> sig != @empty_signature end)
    |> Enum.reduce({:ok, []}, fn sig, acc -> get_spender(hash_no_spenders, sig, acc) end)
  end

  defp get_spender(_hash_no_spenders, _sig, {:error, _} = err), do: err

  defp get_spender(hash_no_spenders, sig, {:ok, spenders}) do
    recovered_address = Crypto.recover_address(hash_no_spenders, sig)

    case recovered_address do
      {:ok, spender} -> {:ok, spenders ++ [spender]}
      error -> error
    end
  end

  @doc """
  Checks if input spenders and recovered transaction's spenders are the same and have the same order
  """
  @spec all_spenders_authorized?(t(), list()) :: :ok
  def all_spenders_authorized?(%__MODULE__{spenders: spenders}, inputs_spenders) do
    if spenders == inputs_spenders, do: :ok, else: {:error, :unauthorized_spent}
  end
end
