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

defmodule OMG.Performance.ByzantineEvents do
  @moduledoc """
  OMG network child chain server byzantine event test. Setup and runs performance byzantine tests.
  """

  require OMG.Utxo
  use OMG.Utils.LoggerExt

  import OMG.Utxo, only: [is_deposit: 1]

  alias OMG.Eth
  alias OMG.Eth.RootChain
  alias OMG.Performance.ByzantineEvents.Mutation
  alias OMG.State.Transaction
  alias OMG.Utils.HttpRPC.Client
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.Utxo

  @watcher_url Application.get_env(:byzantine_events, :watcher_url)

  def start_dos_get_exits(dos_users, positions, url \\ @watcher_url) do
    Enum.map(1..dos_users, fn _ -> worker_dos_get_exit(positions, url) end)
    |> Enum.map(fn task ->
      {time, exits} = Task.await(task, :infinity)
      valid? = Enum.map(exits, &valid_exit_data/1)
      %{time: time, correct: Enum.count(valid?, & &1), error: Enum.count(valid?, &(!&1))}
    end)
  end

  def worker_dos_get_exit(exit_positions, url \\ @watcher_url) do
    worker = fn exit_positions ->
      Enum.map(exit_positions, fn position ->
        get_exit_data(position, url)
      end)
    end

    Task.async(fn ->
      exit_positions = Enum.shuffle(exit_positions)
      :timer.tc(fn -> worker.(exit_positions) end)
    end)
  end

  def start_dos_non_canonical_ife(dos_users, binary_txs, utxos, users, url \\ @watcher_url) do
    Enum.map(1..dos_users, fn _ -> worker_dos_non_canonical_ife(binary_txs, utxos, users, url) end)
    |> Enum.map(fn task ->
      {time, ifes} = Task.await(task, :infinity)
      valid? = Enum.map(ifes, &valid_ife_response/1)
      %{time: time, start_ife: Enum.count(valid?, & &1), not_started_ife: Enum.count(valid?, &(!&1))}
    end)
  end

  def worker_dos_non_canonical_ife(binary_txs, utxos, users, url \\ @watcher_url) do
    {:ok, eth_height} = Eth.get_ethereum_height()
    {:ok, deposits} = RootChain.get_deposits(0, eth_height)
    %{addr: addr} = Enum.random(users)

    worker = fn binary_txs ->
      Stream.map(
        binary_txs,
        &with(
          {:ok, ife} <- compose_in_flight_exit(&1, users, utxos, deposits, url),
          {:ok, txhash} <-
            Eth.RootChainHelper.in_flight_exit(
              ife.in_flight_tx,
              ife.input_txs,
              ife.input_txs_inclusion_proofs,
              ife.in_flight_tx_sigs,
              addr
            ),
          do: {:ok, txhash}
        )
      )
      |> Enum.map(fn
        {:ok, txhash} -> Eth.WaitFor.eth_receipt(txhash, 60_000)
        error -> error
      end)
    end

    Task.async(fn ->
      exit_positions = Enum.shuffle(binary_txs)
      :timer.tc(fn -> worker.(exit_positions) end)
    end)
  end

  def valid_exit_data({:ok, respons}), do: valid_exit_data(respons)
  def valid_exit_data(%{proof: _}), do: true
  def valid_exit_data(_), do: false

  def valid_ife_response({:ok, %{"status" => "0x1"}}), do: true
  def valid_ife_response(_), do: false

  def compose_in_flight_exit(binary_tx, users, utxos, deposits, url \\ @watcher_url) do
    with {:ok, recover_tx} <- Transaction.Recovered.recover_from(binary_tx),
         {:ok, sign_tx} <- Mutation.mutation_tx(recover_tx, utxos, users),
         exit_datas = Transaction.get_inputs(sign_tx) |> Enum.map(&compose_exit(&1, deposits, url)),
         true <- Enum.all?(exit_datas, &match?({:ok, _}, &1)),
         {proofs, input_txs} <-
           exit_datas
           |> Enum.map(fn {:ok, %{proof: proof, txbytes: txbytes}} -> {proof, txbytes} end)
           |> Enum.unzip() do
      input_txs =
        input_txs
        |> Enum.map(&ExRLP.decode/1)
        |> ExRLP.encode()

      sigs = sign_tx.sigs |> Enum.join()
      proofs = Enum.join(proofs)

      {:ok,
       %{
         in_flight_tx: Transaction.raw_txbytes(sign_tx),
         input_txs: input_txs,
         input_txs_inclusion_proofs: proofs,
         in_flight_tx_sigs: sigs
       }}
    else
      false -> {:error, :not_all_inputs_exitable}
      error -> error
    end
  end

  def get_exitable_utxos(addr, watcher_url \\ @watcher_url)

  def get_exitable_utxos(addr, watcher_url) when is_binary(addr) do
    {:ok, utxos} = Client.get_exitable_utxos(addr, watcher_url)
    utxos
  end

  def get_exitable_utxos(%{addr: addr}, watcher_url) when is_binary(addr),
    do: Encoding.to_hex(addr) |> get_exitable_utxos(watcher_url)

  def get_exitable_utxos(users, watcher_url) when is_list(users),
    do: Enum.map(users, &get_exitable_utxos(&1, watcher_url)) |> Enum.concat()

  def get_exit_data(utxo_pos, watcher_url \\ @watcher_url) do
    Client.get_exit_data(utxo_pos, watcher_url)
  rescue
    error -> error
  end

  def compose_exit(utxo_pos, deposits, watcher_url \\ @watcher_url)

  def compose_exit(Utxo.position(blknum, _, _) = utxo_pos, deposits, _)
      when is_deposit(utxo_pos) do
    Enum.find(deposits, fn deposit -> deposit.blknum == blknum end)
    |> OMG.Watcher.UtxoExit.Core.compose_deposit_exit(utxo_pos)
  end

  def compose_exit(utxo_pos, _, watcher_url) do
    utxo_pos
    |> Utxo.Position.encode()
    |> get_exit_data(watcher_url)
  end

  def watcher_synchronize(watcher_url \\ @watcher_url) do
    Eth.WaitFor.repeat_until_ok(fn ->
      with {:ok,
            %{
              last_mined_child_block_number: last_validated_child_block_number,
              last_validated_child_block_number: last_validated_child_block_number
            }} <- Client.get_status(watcher_url) do
        {:ok, last_validated_child_block_number}
      else
        _ -> :repeat
      end
    end)
  end

  def watcher_synchronize_service(service, service_height, watcher_url \\ @watcher_url) do
    Eth.WaitFor.repeat_until_ok(fn ->
      with {:ok, %{services_synced_heights: services_synced_heights}} <- Client.get_status(watcher_url),
           %{"height" => height} when height >= service_height <-
             Enum.find(services_synced_heights, &match?(%{"service" => ^service}, &1)) do
        {:ok, height}
      else
        _ -> :repeat
      end
    end)
  end
end
