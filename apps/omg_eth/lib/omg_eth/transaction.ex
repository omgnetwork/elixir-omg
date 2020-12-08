# Copyright 2019-2020 OmiseGO Pte Ltd
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
  @spec send(:infura, binary()) :: {:ok, OMG.Eth.hash()} | {:error, any()}
  @spec send(atom(), map()) :: {:ok, OMG.Eth.hash()} | {:error, any()}
  def send(backend, txmap) do
    transact(backend, txmap)
  end

  defp transact(:geth, txmap) do
    eth_send_transaction = Ethereumex.HttpClient.eth_send_transaction(txmap)

    case eth_send_transaction do
      {:ok, receipt_enc} -> {:ok, Encoding.from_hex(receipt_enc)}
      other -> other
    end
  end

  defp transact(:infura, transaction_data) do
    case Ethereumex.HttpClient.eth_send_raw_transaction(transaction_data) do
      {:ok, receipt_enc} -> {:ok, Encoding.from_hex(receipt_enc)}
      other -> other
    end
  end
end
