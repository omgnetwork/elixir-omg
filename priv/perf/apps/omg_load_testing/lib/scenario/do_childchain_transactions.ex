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

defmodule OMG.LoadTesting.Scenario.DoChildChainTransactions do
  @moduledoc """
  This scenario tests childchain handling lots of transactions concurrently
  """

  use Chaperon.Scenario

  alias Chaperon.Timing
  alias ExPlasma.Utxo
  alias OMG.LoadTesting.Utils.Account
  alias OMG.LoadTesting.Utils.Faucet

  @eth <<0::160>>
  @fee_wei Application.fetch_env!(:omg_load_testing, :fee_wei)

  defmodule LastTx do
    @moduledoc """
    register last tx to chain the utxo to next transaction
    """
    defstruct [:blknum, :txindex, :oindex, :amount]
    @type t :: %__MODULE__{blknum: integer, txindex: integer, oindex: integer, amount: integer}
  end

  @spec init(Chaperon.Session.t()) :: Chaperon.Session.t()
  def init(session) do
    session
    |> log_info("start init with random delay...")
    |> random_delay(Timing.seconds(5))
  end

  @spec run(Chaperon.Session.t()) :: Chaperon.Session.t()
  def run(session) do
    ntx_to_send = config(session, [:ntx_to_send])
    initial_funds = ntx_to_send + ntx_to_send * @fee_wei
    {:ok, sender} = Account.new()
    {:ok, {utxo, amount}} = Faucet.fund_child_chain_account(sender, initial_funds, @eth)
    {:ok, %{txindex: txindex, oindex: oindex, blknum: blknum}} = Utxo.new(utxo)

    session
    |> Chaperon.Session.assign(last_tx: %LastTx{blknum: blknum, txindex: txindex, oindex: oindex, amount: amount})
    |> repeat(:do_childchain_transaction, [sender, @fee_wei], ntx_to_send)
    |> log_info("end...")
  end

  def do_childchain_transaction(session, sender, fee_wei) do
    last_tx = session.assigned.last_tx
    tx = prepare_new_tx(%{sender: sender, last_tx: last_tx, fee_wei: fee_wei})
    start = Timing.timestamp()

    session
    |> submit_tx(tx)
    |> Chaperon.Session.add_metric(
      {:call, {OMG.LoadTesting.Scenario.DoChildChainTransactions, "ChildChainAPI.Api.Transaction.submit"}},
      Timing.timestamp() - start
    )
  end

  defp submit_tx(session, {inputs, outputs, sender}) do
    {:ok, blknum, txindex} = OMG.LoadTesting.Utils.ChildChain.submit_tx(inputs, outputs, [sender])
    [%{amount: amount} | _] = outputs

    last_tx = %LastTx{
      blknum: blknum,
      txindex: txindex,
      oindex: 0,
      amount: amount
    }

    session
    |> Chaperon.Session.assign(last_tx: last_tx)
    |> log_info("Transaction submitted successfully {#{inspect(blknum)}, #{inspect(txindex)}}")
  end

  defp prepare_new_tx(%{
         sender: sender,
         last_tx: last_tx,
         fee_wei: fee_wei
       }) do
    to_spend = 1
    new_amount = last_tx.amount - to_spend - fee_wei
    {:ok, recipient} = Account.new()
    input = %Utxo{blknum: last_tx.blknum, txindex: last_tx.txindex, oindex: last_tx.oindex}
    recipient_output = [%Utxo{owner: recipient.addr, currency: @eth, amount: to_spend}]

    change_output =
      if new_amount > 0,
        do: [%Utxo{owner: sender.addr, currency: @eth, amount: new_amount}],
        else: []

    {[input], change_output ++ recipient_output, sender}
  end
end
