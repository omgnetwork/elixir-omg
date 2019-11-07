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

defmodule OMG.Eth.Transaction do
  @moduledoc """
  An interface to Ethereum client transact function.
  """
  require Logger
  alias OMG.Eth.Encoding

  @doc """
  Send transaction to be singed by a key managed by Ethereum node, geth or parity.
  For geth, account must be unlocked externally.
  If using parity, account passphrase must be provided directly or via config.
  """
  @spec send(:infura, binary(), OMG.Eth.send_transaction_opts()) :: {:ok, OMG.Eth.hash()} | {:error, any()}
  @spec send(atom(), map(), OMG.Eth.send_transaction_opts()) :: {:ok, OMG.Eth.hash()} | {:error, any()}
  def send(backend, txmap, opts \\ []) do
    transact(backend, txmap, opts)
  end

  # ganache works the same as geth in this aspect
  defp transact(:ganache, txmap, opts), do: transact(:geth, txmap, opts)

  defp transact(:geth, txmap, _opts) do
    case Ethereumex.HttpClient.eth_send_transaction(txmap) do
      {:ok, receipt_enc} -> {:ok, Encoding.from_hex(receipt_enc)}
      other -> other
    end
  end

  defp transact(:infura, transaction_data, _opts) do
    case Ethereumex.HttpClient.eth_send_raw_transaction(transaction_data) do
      {:ok, receipt_enc} -> {:ok, Encoding.from_hex(receipt_enc)}
      other -> other
    end
  end

  defp transact(:parity, txmap, opts) do
    with {:ok, passphrase} <- get_signer_passphrase(txmap.from),
         opts = Keyword.merge([passphrase: passphrase], opts),
         params = [txmap, Keyword.get(opts, :passphrase, "")],
         {:ok, receipt_enc} <- Ethereumex.HttpClient.request("personal_sendTransaction", params, []) do
      {:ok, Encoding.from_hex(receipt_enc)}
    end
  end

  # TODO what is this?
  defp get_signer_passphrase("0x00a329c0648769a73afac7f9381e08fb43dbea72") do
    # Parity coinbase address in dev mode, passphrase is empty
    {:ok, ""}
  end

  defp get_signer_passphrase(_) do
    case System.get_env("SIGNER_PASSPHRASE") do
      nil ->
        _ = Logger.error("Passphrase missing. Please provide the passphrase to Parity managed account.")
        {:error, :passphrase_missing}

      value ->
        {:ok, value}
    end
  end
end
