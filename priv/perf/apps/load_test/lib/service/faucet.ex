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
          utxos: map()
        }
  defstruct [:faucet_account, :fee, utxos: %{}]

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
        fee: Keyword.fetch!(config, :fee_wei)
      )

    {:ok, state}
  end

  def handle_call(:get_faucet, _from, %__MODULE__{faucet_account: faucet_account} = state) do
    {:reply, {:ok, faucet_account}, state}
  end

  def handle_call(
        {:fund_child_chain, receiver, amount, currency},
        _from,
        %__MODULE__{
          faucet_account: faucet_account
        } = state
      ) do
    utxo = check_sufficient_funds(state, currency, amount)

    change = utxo.amount - amount - state.fee
    if change < 0, do: raise({:error, :insufficient_faucet_funds})

    outputs = [
      %Utxo{amount: change, currency: currency, owner: faucet_account.addr},
      %Utxo{amount: amount, currency: currency, owner: receiver.addr}
    ]

    Logger.debug("Funding user #{Encoding.to_hex(receiver.addr)} with #{amount} from utxo: #{Utxo.pos(utxo)}")
    {:ok, blknum, txindex} = Transaction.submit_tx([utxo], outputs, [faucet_account], @fund_child_chain_account_retries)

    next_faucet_utxo = %Utxo{blknum: blknum, txindex: txindex, oindex: 0, amount: change}
    user_utxo = %Utxo{blknum: blknum, txindex: txindex, oindex: 1, amount: amount}

    updated_state = Map.put(state, :utxos, Map.put(state.utxos, currency, next_faucet_utxo))

    {:reply, {:ok, user_utxo}, updated_state}
  end

  @spec check_sufficient_funds(state(), Utxo.address_binary(), pos_integer()) :: Utxo.t()
  defp check_sufficient_funds(
         %{utxos: utxos, faucet_account: faucet_account, fee: fee},
         currency,
         amount
       ) do
    utxo =
      case Map.has_key?(utxos, currency) do
        true ->
          utxos[currency]

        _ ->
          faucet_account.addr
          |> get_utxos()
          |> get_largest_utxo_by_currency(faucet_account, currency)
          |> get_largest_utxo_by_currency(faucet_account, currency)
      end

    case utxo.amount - amount - fee < 0 do
      true -> deposit(faucet_account, currency)
      _ -> utxo
    end
  end

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

  @spec get_largest_utxo_by_currency(list(), Account.t(), Utxo.address_binary()) :: Utxo.t()
  defp get_largest_utxo_by_currency([], faucet_account, currency), do: deposit(faucet_account, currency)

  defp get_largest_utxo_by_currency(utxos, faucet_account, currency) do
    utxos = Enum.filter(utxos, fn utxo -> currency == LoadTest.Utils.Encoding.from_hex(utxo["currency"]) end)

    case length(utxos) do
      0 -> deposit(faucet_account, currency)
      _ -> get_largest_utxo(utxos, currency)
    end
  end

  @spec get_largest_utxo(list(), Utxo.address_binary()) :: Utxo.t()
  defp get_largest_utxo(utxos, _currency) do
    utxo = Enum.max_by(utxos, fn x -> x["amount"] end)

    %Utxo{
      blknum: utxo["blknum"],
      txindex: utxo["txindex"],
      oindex: utxo["oindex"],
      amount: utxo["amount"]
    }
  end

  @spec deposit(Account.t(), Utxo.address_binary()) :: Utxo.t()
  defp deposit(faucet_account, currency) do
    Logger.debug("Not enough funds in the faucet, depositing more from the root chain")

    {:ok, utxo} =
      Deposit.deposit_from(
        faucet_account,
        Application.fetch_env!(:load_test, :faucet_deposit_wei),
        currency,
        Application.fetch_env!(:load_test, :deposit_finality_margin)
      )

    utxo
  end
end
