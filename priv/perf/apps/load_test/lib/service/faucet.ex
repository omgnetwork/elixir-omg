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

defmodule LoadTest.Service.Faucet do
  @moduledoc """
  Handles funding accounts on child chain.
  """

  require Logger

  use GenServer

  alias ExPlasma.Encoding
  alias ExPlasma.Utxo
  alias LoadTest.ChildChain.Deposit
  alias LoadTest.ChildChain.Transaction
  alias LoadTest.Ethereum.Account

  @eth <<0::160>>
  @fund_child_chain_account_retries 100

  defstruct [:account, :fee, utxos: %{}]

  def fund_child_chain_account(account, amount, token) do
    GenServer.call(__MODULE__, {:fund_child_chain, account, amount, token}, :infinity)
  end

  def get_faucet() do
    GenServer.call(__MODULE__, :get_faucet)
  end

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    fee_wei = Keyword.fetch!(config, :fee_wei)

    {faucet, eth_utxo} = get_funded_faucet_account(config)
    Logger.debug("Using faucet: #{Encoding.to_hex(faucet.addr)}")

    state = struct!(__MODULE__, account: faucet, fee: fee_wei, utxos: %{@eth => eth_utxo})
    {:ok, state}
  end

  def handle_call(:get_faucet, _from, %__MODULE__{account: faucet} = state) do
    {:reply, {:ok, faucet}, state}
  end

  def handle_call({:fund_child_chain, account, amount, @eth = token}, _from, %__MODULE__{account: faucet} = state) do
    {utxo, utxo_amount} = state.utxos[token]
    change = utxo_amount - amount - state.fee
    if change < 0, do: raise({:error, :change_below_zero})

    Logger.debug("Funding user: #{Encoding.to_hex(account.addr)} with UTXO: #{Utxo.pos(utxo)}")

    outputs = [
      %Utxo{amount: change, currency: token, owner: faucet.addr},
      %Utxo{amount: amount, currency: token, owner: account.addr}
    ]

    {:ok, blknum, txindex} = Transaction.submit_tx([utxo], outputs, [faucet], @fund_child_chain_account_retries)
    {:ok, change_utxo} = Utxo.new(%{blknum: blknum, txindex: txindex, oindex: 0})
    {:ok, user_utxo} = Utxo.new(%{blknum: blknum, txindex: txindex, oindex: 1, amount: amount})

    updated_state = Map.put(state, :utxos, %{state.utxos | token => {change_utxo, change}})

    {:reply, {:ok, user_utxo}, updated_state}
  end

  defp get_funded_faucet_account(opts) do
    faucet_private_key = Keyword.fetch!(opts, :faucet_private_key)
    {:ok, faucet} = Account.new(faucet_private_key)

    deposit_amount = Keyword.fetch!(opts, :faucet_deposit_wei)
    deposit_finality_margin = Keyword.fetch!(opts, :deposit_finality_margin)
    {:ok, deposit_utxo} = Deposit.deposit_from(faucet, deposit_amount, @eth, deposit_finality_margin)

    {faucet, {deposit_utxo, deposit_amount}}
  end
end
