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

defmodule OMG.LoadTest.Utils.Faucet do
  require Logger

  use GenServer

  alias ExPlasma.Encoding
  alias ExPlasma.Utxo
  alias OMG.LoadTest.Utils.Account
  alias OMG.LoadTest.Utils.ChildChain
  alias OMG.LoadTest.Utils.Deposit
  alias OMG.LoadTest.Utils.Ethereum, as: Eth

  @eth <<0::160>>
  @fund_child_chain_account_retries 100

  defstruct [:account, :fee, utxos: %{}]

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def fund_child_chain_account(account, amount, token) do
    GenServer.call(__MODULE__, {:fund_child_chain, account, amount, token}, :infinity)
  end

  def init(_) do
    opts = fetch_default_opts()
    fee_wei = Keyword.fetch!(opts, :fee_wei)

    {faucet, eth_utxo} = get_funded_faucet_account(opts)
    Logger.debug("Using faucet: #{Encoding.to_hex(faucet.addr)}")

    state = struct!(__MODULE__, account: faucet, fee: fee_wei, utxos: %{@eth => eth_utxo})
    {:ok, state}
  end

  def handle_call(
        {:fund_child_chain, account, amount, @eth = token},
        _from,
        %__MODULE__{account: faucet} = state
      ) do
    {utxo, utxo_amount} = state.utxos[token]
    change = utxo_amount - amount - state.fee
    if change < 0, do: raise({:error, :change_below_zero})

    Logger.debug("Funding user: #{Encoding.to_hex(account.addr)} with UTXO: #{Utxo.pos(utxo)}")

    outputs = [
      %Utxo{amount: change, currency: token, owner: faucet.addr},
      %Utxo{amount: amount, currency: token, owner: account.addr}
    ]

    {:ok, blknum, txindex} = ChildChain.submit_tx([utxo], outputs, [faucet], @fund_child_chain_account_retries)

    {:ok, change_utxo} = Utxo.new(%{blknum: blknum, txindex: txindex, oindex: 0})
    {:ok, user_utxo} = Utxo.new(%{blknum: blknum, txindex: txindex, oindex: 1})

    updated_state = Map.put(state, :utxos, %{state.utxos | token => {change_utxo, change}})

    {:reply, {:ok, {Utxo.pos(user_utxo), amount}}, updated_state}
  end

  defp get_funded_faucet_account(opts) do
    faucet =
      case Keyword.fetch(opts, :faucet) do
        {:ok, faucet} ->
          faucet

        :error ->
          Logger.debug("Generating a faucet")
          {:ok, faucet} = create_funded_faucet(opts)
          faucet
      end

    deposit_amount = Keyword.fetch!(opts, :faucet_deposit_wei)
    deposit_finality_margin = Keyword.fetch!(opts, :deposit_finality_margin)

    {:ok, deposit_utxo} = Deposit.deposit_from(faucet, deposit_amount, @eth, deposit_finality_margin)

    {faucet, {deposit_utxo, deposit_amount}}
  end

  defp create_funded_faucet(opts) do
    # Sends a transaction to a local instance of geth.
    # NOTE: Assumes existence of an unlocked account managed by Ethereum client.

    faucet_initial_funds = Keyword.fetch!(opts, :faucet_default_funds)
    {:ok, account} = Account.new()

    {:ok, _} = Eth.fund_address_from_default_faucet(account, initial_funds_wei: faucet_initial_funds)

    {:ok, account}
  end

  defp fetch_default_opts() do
    faucet_opt =
      case Application.fetch_env(:omg_load_test, :faucet_account) do
        {:ok, %{priv: priv}} ->
          {:ok, faucet_account} = priv |> Encoding.to_binary() |> Account.new()
          [faucet: faucet_account]

        :error ->
          []
      end

    [:fee_wei, :faucet_default_funds, :faucet_deposit_wei, :deposit_finality_margin]
    |> Enum.reduce([], fn key, acc ->
      [{key, Application.fetch_env!(:omg_load_test, key)} | acc]
    end)
    |> Keyword.merge(faucet_opt)
  end
end
