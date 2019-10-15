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
  import OMG.Eth.Encoding, only: [from_hex: 1]

  @doc """
  Send transaction to be singed by a key managed by Ethereum node, geth or parity.
  For geth, account must be unlocked externally.
  If using parity, account passphrase must be provided directly or via config.
  """
  @spec send(map(), OMG.Eth.send_transaction_opts()) :: {:ok, OMG.Eth.hash()} | {:error, any()}
  def send(txmap, opts \\ []) do
    backend = String.to_existing_atom(Application.fetch_env!(:omg_eth, :eth_node))

    case backend do
      node when node == :geth or node == :infura ->
        with {:ok, receipt_enc} <- Ethereumex.HttpClient.eth_send_transaction(txmap), do: {:ok, from_hex(receipt_enc)}

      :parity ->
        with {:ok, passphrase} <- get_signer_passphrase(txmap.from),
             opts = Keyword.merge([passphrase: passphrase], opts),
             params = [txmap, Keyword.get(opts, :passphrase, "")],
             {:ok, receipt_enc} <- Ethereumex.HttpClient.request("personal_sendTransaction", params, []) do
          {:ok, from_hex(receipt_enc)}
        end
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
