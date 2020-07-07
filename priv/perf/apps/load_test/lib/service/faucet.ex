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

  For simplicity, the faucet will always use its largest value utxo to fund other accounts.
  If its largest value utxo is insufficient (or if it has no utxos) it will do a deposit,
  wait for it to finalize and then use that deposit utxo for funding accounts.

  This means that faucet account must have sufficient funds on the root chain.

  After a few test runs, the faucet can end up with a large amount of utxos. This is not a
  problem per se, but keeping the number of utxos down can speed things up.
  You can merge utxos periodically by running merge_utxos e.g.

  MIX_ENV=test mix run -e "LoadTest.Service.Faucet.merge_utxos(<<0::160>>)"
  """

  require Logger

  use GenServer

  alias ExPlasma.Encoding
  alias ExPlasma.Utxo
  alias LoadTest.ChildChain.Deposit
  alias LoadTest.ChildChain.Transaction
  alias LoadTest.ChildChain.Utxos
  alias LoadTest.Ethereum.Account

  # Submitting a transaction to the childchain can fail if it is under heavy load,
  # allow the faucet to retry to avoid failing the test prematurely.
  @fund_child_chain_account_retries 100

  @type state :: %__MODULE__{
          faucet_account: Account.t(),
          fee: pos_integer(),
          faucet_deposit_amount: pos_integer(),
          deposit_finality_margin: pos_integer(),
          gas_price: pos_integer(),
          utxos: map()
        }
  defstruct [:faucet_account, :fee, :faucet_deposit_amount, :deposit_finality_margin, :gas_price, utxos: %{}]

  @doc """
  Sends funds to an account on the childchain.
  If the faucet doesn't have enough funds it will deposit more. Note that this can take some time to finalize.
  """
  @spec fund_child_chain_account(Account.t(), pos_integer(), Utxo.address_binary()) :: Utxo.t()
  def fund_child_chain_account(receiver, amount, currency) when byte_size(currency) == 20 do
    GenServer.call(__MODULE__, {:fund_child_chain, receiver, amount, currency}, :infinity)
  end

  def fund_child_chain_account(receiver, amount, currency) do
    fund_child_chain_account(receiver, amount, Encoding.to_binary(currency))
  end

  @doc """
  Returns the faucet account.
  """
  @spec get_faucet() :: Account.t()
  def get_faucet() do
    GenServer.call(__MODULE__, :get_faucet)
  end

  @doc """
  Merges all the utxos of the given currency into one.
  Note that this can take some time.
  """
  @spec merge_utxos(Utxo.address_binary()) :: Utxo.t()
  def merge_utxos(currency) when byte_size(currency) == 20 do
    GenServer.call(__MODULE__, {:merge_utxos, currency}, :infinity)
  end

  @spec merge_utxos(Utxo.address_hex()) :: Utxo.t()
  def merge_utxos(currency), do: merge_utxos(Encoding.to_binary(currency))

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    {:ok, faucet_account} = Account.new(Keyword.fetch!(config, :faucet_private_key))
    Logger.debug("Using faucet: #{Encoding.to_hex(faucet_account.addr)}")

    state =
      struct!(
        __MODULE__,
        faucet_account: faucet_account,
        fee: Keyword.fetch!(config, :fee_amount),
        faucet_deposit_amount: Keyword.fetch!(config, :faucet_deposit_amount),
        deposit_finality_margin: Keyword.fetch!(config, :deposit_finality_margin),
        gas_price: Keyword.fetch!(config, :gas_price)
      )

    {:ok, state}
  end

  def handle_call(:get_faucet, _from, state) do
    {:reply, {:ok, state.faucet_account}, state}
  end

  def handle_call({:fund_child_chain, receiver, amount, currency}, _from, state) do
    utxo = get_funding_utxo(state, currency, amount)

    Logger.debug("Funding user #{Encoding.to_hex(receiver.addr)} with #{amount} from utxo: #{Utxo.pos(utxo)}")

    outputs =
      Transaction.spend_utxo(
        utxo,
        amount,
        state.fee,
        state.faucet_account,
        receiver,
        currency,
        @fund_child_chain_account_retries
      )

    [next_faucet_utxo, user_utxo] =
      case outputs do
        [single_output] -> [nil, single_output]
        [change_output, user_output] -> [change_output, user_output]
      end

    updated_state = Map.put(state, :utxos, Map.put(state.utxos, currency, next_faucet_utxo))

    {:reply, {:ok, user_utxo}, updated_state}
  end

  def handle_call({:merge_utxos, currency}, _from, state) do
    utxos = Utxos.get_utxos(state.faucet_account.addr)
    Logger.debug("Merging #{length(utxos)} utxos of #{Encoding.to_hex(currency)}")
    utxo = Utxos.merge(utxos, currency, state.faucet_account)
    {:reply, {:ok, utxo}, state}
  end

  @spec get_funding_utxo(state(), Utxo.address_binary(), pos_integer()) :: Utxo.t()
  defp get_funding_utxo(state, currency, amount) do
    utxo = choose_largest_utxo(state.utxos[currency], state.faucet_account, currency)

    if utxo == nil or utxo.amount - amount - state.fee < 0 do
      deposit(
        state.faucet_account,
        max(state.faucet_deposit_amount, amount + state.fee),
        currency,
        state.deposit_finality_margin,
        state.gas_price
      )
    else
      utxo
    end
  end

  defp choose_largest_utxo(nil, account, currency) do
    account.addr
    |> Utxos.get_utxos()
    |> Utxos.get_largest_utxo(currency)
  end

  defp choose_largest_utxo(utxo, _account, _currency), do: utxo

  @spec deposit(Account.t(), pos_integer(), Utxo.address_binary(), pos_integer(), pos_integer()) :: Utxo.t()
  defp deposit(faucet_account, amount, currency, deposit_finality_margin, gas_price) do
    Logger.debug("Not enough funds in the faucet, depositing #{amount} from the root chain")

    {:ok, utxo} = Deposit.deposit_from(faucet_account, amount, currency, deposit_finality_margin, gas_price)
    utxo
  end
end
