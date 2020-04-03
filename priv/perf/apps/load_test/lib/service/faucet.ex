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
  """

  require Logger

  use GenServer

  alias ExPlasma.Encoding
  alias ExPlasma.Utxo
  alias LoadTest.ChildChain.Deposit
  alias LoadTest.ChildChain.Transaction
  alias LoadTest.Connection.WatcherInfo, as: Connection
  alias LoadTest.Ethereum.Account
  alias WatcherInfoAPI.Api
  alias WatcherInfoAPI.Model

  # Submitting a transaction to the childchain can fail if it is under heavy load,
  # allow the faucet to retry to avoid failing the test prematurely.
  @fund_child_chain_account_retries 100

  @type state :: %__MODULE__{
          faucet_account: Account.t(),
          fee: pos_integer(),
          faucet_deposit_wei: pos_integer(),
          deposit_finality_margin: pos_integer(),
          utxos: map()
        }
  defstruct [:faucet_account, :fee, :faucet_deposit_wei, :deposit_finality_margin, utxos: %{}]

  @doc """
  Sends funds to an account on the childchain.
  If the faucet doesn't have enough funds it will deposit more. Note that this can take some time to finalize.
  """
  @spec fund_child_chain_account(Account.t(), pos_integer(), Utxo.address_binary()) :: Utxo.t()
  def fund_child_chain_account(receiver, amount, currency) do
    GenServer.call(__MODULE__, {:fund_child_chain, receiver, amount, currency}, :infinity)
  end

  @doc """
  Returns the faucet account.
  """
  @spec get_faucet() :: Account.t()
  def get_faucet() do
    GenServer.call(__MODULE__, :get_faucet)
  end

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
        fee: Keyword.fetch!(config, :fee_wei),
        faucet_deposit_wei: Keyword.fetch!(config, :faucet_deposit_wei),
        deposit_finality_margin: Keyword.fetch!(config, :deposit_finality_margin)
      )

    {:ok, state}
  end

  def handle_call(:get_faucet, _from, state) do
    {:reply, {:ok, state.faucet_account}, state}
  end

  def handle_call({:fund_child_chain, receiver, amount, currency}, _from, state) do
    utxo = get_funding_utxo(state, currency, amount)

    change = utxo.amount - amount - state.fee

    outputs = [
      %Utxo{amount: change, currency: currency, owner: state.faucet_account.addr},
      %Utxo{amount: amount, currency: currency, owner: receiver.addr}
    ]

    Logger.debug("Funding user #{Encoding.to_hex(receiver.addr)} with #{amount} from utxo: #{Utxo.pos(utxo)}")

    {:ok, blknum, txindex} =
      Transaction.submit_tx([utxo], outputs, [state.faucet_account], @fund_child_chain_account_retries)

    next_faucet_utxo = %Utxo{blknum: blknum, txindex: txindex, oindex: 0, amount: change}
    user_utxo = %Utxo{blknum: blknum, txindex: txindex, oindex: 1, amount: amount}

    updated_state = Map.put(state, :utxos, Map.put(state.utxos, currency, next_faucet_utxo))

    {:reply, {:ok, user_utxo}, updated_state}
  end

  @spec get_funding_utxo(state(), Utxo.address_binary(), pos_integer()) :: Utxo.t()
  defp get_funding_utxo(state, currency, amount) do
    utxo = choose_largest_utxo(state.utxos[currency], state.faucet_account, currency)

    case utxo == nil or utxo.amount - amount - state.fee < 0 do
      true ->
        deposit(
          state.faucet_account,
          max(state.faucet_deposit_wei, amount + state.fee),
          currency,
          state.deposit_finality_margin
        )

      _ ->
        utxo
    end
  end

  defp choose_largest_utxo(nil, account, currency) do
    account.addr
    |> get_utxos()
    |> get_largest_utxo_by_currency(currency)
  end

  defp choose_largest_utxo(utxo, _account, _currency), do: utxo

  @spec get_utxos(Utxo.address_binary()) :: list()
  defp get_utxos(address) do
    {:ok, response} =
      Api.Account.account_get_utxos(
        Connection.client(),
        %Model.AddressBodySchema1{
          address: Encoding.to_hex(address)
        }
      )

    Jason.decode!(response.body)["data"]
  end

  @spec get_largest_utxo_by_currency(list(), Utxo.address_binary()) :: Utxo.t()
  defp get_largest_utxo_by_currency([], _currency), do: nil

  defp get_largest_utxo_by_currency(utxos, currency) do
    utxos
    |> Enum.filter(fn utxo -> currency == LoadTest.Utils.Encoding.from_hex(utxo["currency"]) end)
    |> get_largest_utxo()
  end

  @spec get_largest_utxo(list()) :: Utxo.t()
  defp get_largest_utxo([]), do: nil

  defp get_largest_utxo(utxos) do
    utxo = Enum.max_by(utxos, & &1["amount"])

    %Utxo{
      blknum: utxo["blknum"],
      txindex: utxo["txindex"],
      oindex: utxo["oindex"],
      amount: utxo["amount"]
    }
  end

  @spec deposit(Account.t(), pos_integer(), Utxo.address_binary(), pos_integer()) :: Utxo.t()
  defp deposit(faucet_account, amount, currency, deposit_finality_margin) do
    Logger.debug("Not enough funds in the faucet, depositing more from the root chain")

    {:ok, utxo} = Deposit.deposit_from(faucet_account, amount, currency, deposit_finality_margin)
    utxo
  end
end
