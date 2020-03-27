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

defmodule LoadTest.Scenario.ChildChainSubmitTransactions do
  @moduledoc """
  This scenario tests childchain handling lots of transactions concurrently
  """

  use Chaperon.Scenario

  alias Chaperon.Timing
  alias ExPlasma.Utxo
  alias LoadTest.Ethereum.Account
  alias LoadTest.Service.Faucet

  @eth <<0::160>>

  @spec run(Chaperon.Session.t()) :: Chaperon.Session.t()
  def run(session) do
    fee_wei = Application.fetch_env!(:load_test, :fee_wei)

    # Create a new account and fund it from the faucet
    {:ok, sender} = LoadTest.Ethereum.Account.new()
    ntx_to_send = config(session, [:ntx_to_send])
    initial_funds = ntx_to_send + ntx_to_send * fee_wei
    {:ok, utxo} = Faucet.fund_child_chain_account(sender, initial_funds, @eth)

    session
    |> Chaperon.Session.assign(next_utxo: utxo)
    |> repeat(:send_tx, [sender, fee_wei], ntx_to_send)
  end

  def send_tx(session, sender, fee_wei) do
    utxo = session.assigned.next_utxo
    tx = prepare_new_tx(%{sender: sender, utxo: utxo, fee_wei: fee_wei})

    start = Timing.timestamp()

    session
    |> submit_tx(tx)
    |> Chaperon.Session.add_metric(
      {:call, {LoadTest.Scenario.ChildChainSubmitTransactions, "ChildChain.Transaction.submit"}},
      Timing.timestamp() - start
    )
  end

  defp prepare_new_tx(%{
         sender: sender,
         utxo: utxo,
         fee_wei: fee_wei
       }) do
    to_spend = 1
    new_amount = utxo.amount - to_spend - fee_wei
    {:ok, recipient} = Account.new()
    recipient_output = [%Utxo{owner: recipient.addr, currency: @eth, amount: to_spend}]

    change_output =
      if new_amount > 0,
        do: [%Utxo{owner: sender.addr, currency: @eth, amount: new_amount}],
        else: []

    {[utxo], change_output ++ recipient_output, sender}
  end

  defp submit_tx(session, {inputs, outputs, sender}) do
    {:ok, blknum, txindex} = LoadTest.ChildChain.Transaction.submit_tx(inputs, outputs, [sender])
    [%{amount: amount} | _] = outputs
    {:ok, next_utxo} = Utxo.new(%{blknum: blknum, txindex: txindex, oindex: 0, amount: amount})

    session
    |> Chaperon.Session.assign(next_utxo: next_utxo)
    |> log_info("Transaction submitted successfully {#{inspect(blknum)}, #{inspect(txindex)}}")
  end
end
