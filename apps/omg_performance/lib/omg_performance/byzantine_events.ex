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
  OMG network child chain server byzantine event test entrypoint. Runs performance byzantine tests.

  ## Usage

  To setup, once you have your Ethereum node and a child chain running, from a configured `iex -S mix run --no-start`
  shell do:

  ```
  use OMG.Performance

  Performance.init()
  spenders = Generators.generate_users(2)
  ```

  You probably want to prefill the child chain with transactions, see `OMG.Performance.ExtendedPerftest` or just:
  ```
  Performance.ExtendedPerftest.start(10_000, 16, randomized: false)
  ```
  (`randomized: false` is useful to test massive honest-standard-exiting, since it will create many unspent UTXOs for
  each of the spenders)
  """

  use OMG.Utils.LoggerExt

  alias OMG.Performance.HttpRPC.WatcherClient
  alias OMG.Performance.ByzantineEvents.TransactionCreator
  alias OMG.Utils.HttpRPC.Encoding
  alias OMG.State.Transaction
  alias Support.WaitFor

  @doc """
  For given utxo positions shuffle them and ask the watcher for exit data

  ## Usage

  On top of the generic setup (see above) do:

  ```
  alice = Enum.at(spenders, 0)

  :ok = ByzantineEvents.watcher_synchronize()

  utxo_positions = ByzantineEvents.get_exitable_utxos(alice.addr, take: 20)
  exit_datas = timeit ByzantineEvents.get_many_standard_exits(utxo_positions)
  ```

  **NOTE** this uses unspent UTXOs creating valid exits for `alice`. For invalid exits do

  ```
  utxo_positions = Generators.stream_utxo_positions(owned_by: alice.addr, take: 20)
  ```
  """
  @spec get_many_standard_exits(list(pos_integer())) :: list(map())
  def get_many_standard_exits(exit_positions) do
    exit_positions
    |> Enum.shuffle()
    |> Enum.map(&WatcherClient.get_exit_data/1)
    |> only_successes()
  end

  @doc """
  For given standard exit datas (maps received from the Watcher) start all the exits in the root chain contract.

  Will use `owner_address` to start the exits so this address must own all the supplied UTXOs to exit.

  Will send out all transactions concurrently, fail if any of them fails and block till the last gets mined. Returns
  the receipt of the last transaction sent out.
  """
  @spec start_many_exits(list(map), OMG.Crypto.address_t()) :: {:ok, map()} | {:error, any()}
  def start_many_exits(exit_datas, owner_address) do
    map_contract_transaction(exit_datas, fn composed_exit ->
      Support.RootChainHelper.start_exit(
        composed_exit.utxo_pos,
        composed_exit.txbytes,
        composed_exit.proof,
        owner_address
      )
    end)
  end

  @doc """
  For given transactions shuffle them and ask the watcher for IFE data

  ## Usage

  On top of the generic setup (see above) do:

  ```
  alice = Enum.at(spenders, 0)
  :ok = ByzantineEvents.watcher_synchronize()

  transactions =
    ByzantineEvents.get_exitable_utxos(alice.addr, take: 5) \
    |> ByzantineEvents.get_many_new_txs(alice)

  ife_datas = timeit ByzantineEvents.get_many_ifes(transactions)
  ```

  **NOTE** this uses unspent UTXOs creating valid IFEs for `alice`. For invalid IFEs (double-spent inputs) do

  transactions =
    Generators.stream_transactions(sent_by: alice.addr, take: 50, no_deposit_spends: true) \
    |> ByzantineEvents.Mutations.mutate_txs([alice.priv])

  ife_datas = timeit ByzantineEvents.get_many_ifes(transactions)
  ```

  This will IFE using mutated versions of included txs, the IFEs will be non-canonical
  """
  @spec get_many_ifes(list(Transaction.Signed.tx_bytes())) :: list(map())
  def get_many_ifes(txs) do
    txs
    |> Enum.shuffle()
    |> Enum.map(&WatcherClient.get_in_flight_exit/1)
    |> only_successes()
  end

  @doc """
  For given utxo positions, craft some more transactions from the `owner`. Transactions return follow the same format
  as `OMG.Performance.Generators.stream_transactions` and are ready to push to `get_many_ifes`

  ## Usage

  On top of the generic setup (see above) do:

  ```
  transactions =
    ByzantineEvents.get_exitable_utxos(alice.addr, take: 5) \
    |> ByzantineEvents.get_many_new_txs(alice)
  ```
  """
  @spec get_many_new_txs(list(pos_integer()), OMG.TestHelper.entity()) :: list(Transaction.Signed.tx_bytes())
  def get_many_new_txs(encoded_utxo_positions, user),
    do: Enum.map(encoded_utxo_positions, &TransactionCreator.spend_utxo_by(&1, user.addr, user.priv, 1))

  @doc """
  For given IFE datas (maps received from the Watcher) start all the exits in the root chain contract.

  Will use `user_address` to start the exits, it can be any funded address.

  Will send out all transactions concurrently, fail if any of them fails and block till the last gets mined. Returns
  the receipt of the last transaction sent out.
  """
  @spec start_many_ifes(list(map), OMG.Crypto.address_t()) :: {:ok, map()} | {:error, any()}
  def start_many_ifes(ife_datas, user_address) do
    map_contract_transaction(ife_datas, fn ife ->
      Support.RootChainHelper.in_flight_exit(
        ife.in_flight_tx,
        ife.input_txs,
        ife.input_utxos_pos,
        ife.input_txs_inclusion_proofs,
        ife.in_flight_tx_sigs,
        user_address
      )
    end)
  end

  @doc """
  For given transactions shuffle them and ask the watcher for piggyback data (inputs or outputs)

  ## Usage

  On top of the generic setup, with many IFEs started by `alice` from `transactions` (see above) do:

  NOTE this uses inputs/outputs of the provided transactions, so the piggybacks' validity will depend on what txs those
  are

  ```
  piggyback_datas = ByzantineEvents.get_many_piggybacks(transactions)
  ```

  For a nicer way to start _valid_ piggybacks see `get_many_piggybacks_from_available`

  **NOTE** no point in timing it, it doesn't ask the watcher as the piggyback data is trivial to obtain
  """
  @spec get_many_piggybacks(list(Transaction.Signed.tx_bytes()), keyword()) :: list(map())
  def get_many_piggybacks(txs, opts \\ []) do
    output_index = Keyword.get(opts, :output_index, 0)
    type = Keyword.get(opts, :piggyback_type, :input)

    txs
    |> Enum.shuffle()
    |> Enum.map(&Transaction.Signed.decode!/1)
    |> Enum.map(&%{raw_txbytes: Transaction.raw_txbytes(&1), output_index: output_index, piggyback_type: type})
  end

  @doc """
  For given replies from `status.get` ("piggyback_available" field), asks the watcher for piggyback data (all)

  ## Usage

  On top of the generic setup, with many IFEs started by `alice` from `transactions` (see above) do:

  ```
  available = ByzantineEvents.get_byzantine_events("piggyback_available")
  piggyback_datas = ByzantineEvents.get_many_piggybacks_from_available(available)
  ```

  **NOTE** no point in timing it, it doesn't ask the watcher as the piggyback data is trivial to obtain
  """
  @spec get_many_piggybacks_from_available(list(map())) :: list(map())
  def get_many_piggybacks_from_available(available_entries) do
    Enum.flat_map(available_entries, fn {txbytes, inputs, outputs} ->
      input_piggybacks = Enum.map(inputs, &%{raw_txbytes: txbytes, output_index: &1, piggyback_type: :input})
      output_piggybacks = Enum.map(outputs, &%{raw_txbytes: txbytes, output_index: &1, piggyback_type: :output})
      Enum.concat(input_piggybacks, output_piggybacks)
    end)
  end

  @doc """
  For given piggyback datas (maps received from the Watcher) piggyback in the root chain contract.

  Will use `user_address` to start the exits, it can be any funded address.

  Will send out all transactions concurrently, fail if any of them fails and block till the last gets mined. Returns
  the receipt of the last transaction sent out.
  """
  @spec start_many_piggybacks(list(map), OMG.Crypto.address_t()) :: {:ok, map()} | {:error, any()}
  def start_many_piggybacks(piggyback_datas, user_address) do
    map_contract_transaction(piggyback_datas, fn piggyback ->
      case piggyback.piggyback_type do
        :input ->
          Support.RootChainHelper.piggyback_in_flight_exit_on_input(
            piggyback.raw_txbytes,
            piggyback.output_index,
            user_address
          )

        :output ->
          Support.RootChainHelper.piggyback_in_flight_exit_on_output(
            piggyback.raw_txbytes,
            piggyback.output_index,
            user_address
          )
      end
    end)
  end

  @doc """
  For given utxo positions shuffle them and ask the watcher for challenge data. All positions must be invalid exits

  ## Usage

  Having some invalid exits out there (see above), last of which started at `last_exit_height`, do:

  ```
  :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)
  utxos_to_challenge = timeit ByzantineEvents.get_byzantine_events("invalid_exit")
  challenge_responses = timeit ByzantineEvents.get_many_se_challenges(utxos_to_challenge)
  ```
  """
  @spec get_many_se_challenges(list(pos_integer())) :: list(map())
  def get_many_se_challenges(positions) do
    positions
    |> Enum.shuffle()
    |> Enum.map(&WatcherClient.get_exit_challenge/1)
    |> only_successes()
  end

  @doc """
  For given challenges (maps received from the Watcher) challenge all the invalid exits in the root chain contract.

  Will use `challenger_address`, which can be any well-funded address.

  Will send out all transactions concurrently, fail if any of them fails and block till the last gets mined. Returns
  the receipt of the last transaction sent out.
  """
  @spec challenge_many_exits(list(map), OMG.Crypto.address_t()) :: {:ok, map()} | {:error, any()}
  def challenge_many_exits(challenge_responses, challenger_address) do
    map_contract_transaction(challenge_responses, fn challenge ->
      Support.RootChainHelper.challenge_exit(
        challenge.exit_id,
        challenge.exiting_tx,
        challenge.txbytes,
        challenge.input_index,
        challenge.sig,
        challenger_address
      )
    end)
  end

  @doc """
  For given transactions shuffle them and ask the watcher for IFE challenge data. All transactions must ones that were
  used to start non-canonical IFEs with viable competitors known

  ## Usage

  Having some challengable IFEs out there (see above), last of which started at `last_exit_height`, do:

  ```
  :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)
  to_challenge = timeit ByzantineEvents.get_byzantine_events("non_canonical_ife")
  challenge_responses = timeit ByzantineEvents.get_many_non_canonical_proofs(to_challenge)
  ```
  """
  @spec get_many_non_canonical_proofs(list(Transaction.txbytes())) :: list(map())
  def get_many_non_canonical_proofs(txs) do
    txs
    |> Enum.shuffle()
    |> Enum.map(&WatcherClient.get_in_flight_exit_competitors/1)
    |> only_successes()
  end

  @doc """
  For given transactions shuffle them and ask the watcher for invalid-IFE challenge data. Returns whatever
  `get_many_non_canonical_proofs/1` returns and takes in a collection of IFE txs, but has a bunch of caveats:
    - caller must provide a matching collection of transactions that are competitors to the IFE txs
    - the double-spent inputs must always be on position 0 in all the transactions, both IFE txs and competitors given
    - **NOTE** this hackingly uses the `get_in_flight_exit` call, in order to easly get to the input txs data

  Observe, that this is a quite limited helper, covering for something that the Watcher doesn't support, being a
  byzantine action - opening invalid IFE challenges; hence the hackiness.

  ## Usage

  Having some IFEs out there (see above), last of which started at `last_exit_height`, do:

  ```
  :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)
  mutated_transactions = ByzantineEvents.Mutations.mutate_txs(transactions, [alice.priv])
  to_challenge = timeit ByzantineEvents.get_many_invalid_non_canonical_proofs(transactions, mutated_transactions)
  challenge_responses = timeit ByzantineEvents.get_many_non_canonical_proofs(to_challenge)
  ```
  """
  @spec get_many_invalid_non_canonical_proofs(list(Transaction.Signed.txbytes()), list(Transaction.Signed.txbytes())) ::
          list(map())
  def get_many_invalid_non_canonical_proofs(in_flight_txs, competitor_txs) do
    competitor_txs
    |> Enum.map(&WatcherClient.get_in_flight_exit/1)
    |> only_successes()
    |> Enum.zip(in_flight_txs)
    |> Enum.map(fn {mutated_tx_ife_data, txbytes} ->
      tx = OMG.State.Transaction.Signed.decode!(txbytes)

      %{
        competing_input_index: 0,
        competing_proof: <<>>,
        competing_sig: Enum.at(mutated_tx_ife_data.in_flight_tx_sigs, 0),
        competing_tx_pos: 0,
        competing_txbytes: mutated_tx_ife_data.in_flight_tx,
        in_flight_input_index: 0,
        in_flight_txbytes: OMG.State.Transaction.raw_txbytes(tx),
        input_tx: Enum.at(mutated_tx_ife_data.input_txs, 0),
        input_utxo_pos: Enum.at(mutated_tx_ife_data.input_utxos_pos, 0)
      }
    end)
  end

  @doc """
  For given challenges (maps received from the Watcher) challenge all the invalid exits in the root chain contract.

  Will use `challenger_address`, which can be any well-funded address.

  Will send out all transactions concurrently, fail if any of them fails and block till the last gets mined. Returns
  the receipt of the last transaction sent out.
  """
  @spec prove_many_non_canonical(list(map), OMG.Crypto.address_t()) :: {:ok, map()} | {:error, any()}
  def prove_many_non_canonical(challenge_responses, challenger_address) do
    map_contract_transaction(challenge_responses, fn challenge ->
      Support.RootChainHelper.challenge_in_flight_exit_not_canonical(
        challenge.input_tx,
        challenge.input_utxo_pos,
        challenge.in_flight_txbytes,
        challenge.in_flight_input_index,
        challenge.competing_txbytes,
        challenge.competing_input_index,
        challenge.competing_tx_pos,
        challenge.competing_proof,
        challenge.competing_sig,
        challenger_address
      )
    end)
  end

  @doc """
  For given transactions shuffle them and ask the watcher for responses to invalid IFE challenges. All transactions must
  ones that were used to start a canonical IFEs with invalid competitors being used to challenge canonicity.

  ## Usage

  Having some badly challenged IFEs out there (see above), last of which started at `last_exit_height`, do:

  ```
  :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)
  to_challenge = timeit ByzantineEvents.get_byzantine_events("invalid_ife_challenge")
  challenge_responses = timeit ByzantineEvents.get_many_canonicity_responses(to_challenge)
  ```
  """
  @spec get_many_canonicity_responses(list(Transaction.Signed.txbytes())) :: list(map())
  def get_many_canonicity_responses(txs) do
    txs
    |> Enum.shuffle()
    |> Enum.map(&WatcherClient.get_prove_canonical/1)
    |> only_successes()
  end

  @doc """
  For given challenges (maps received from the Watcher) challenge all the invalid exits in the root chain contract.

  Will use `challenger_address`, which can be any well-funded address.

  Will send out all transactions concurrently, fail if any of them fails and block till the last gets mined. Returns
  the receipt of the last transaction sent out.
  """
  @spec send_many_canonicity_responses(list(map), OMG.Crypto.address_t()) :: {:ok, map()} | {:error, any()}
  def send_many_canonicity_responses(response_responses, responder_address) do
    map_contract_transaction(response_responses, fn response ->
      Support.RootChainHelper.respond_to_non_canonical_challenge(
        response.in_flight_txbytes,
        response.in_flight_tx_pos,
        response.in_flight_proof,
        responder_address
      )
    end)
  end

  @doc """
  For given a collection of `{transaction, invalid_input_ids, invalid_output_ids}` shuffle them and ask the watcher for
  corresponding piggyback challenges. All transactions must ones that were used to start IFEs having invalid piggybacks

  ## Usage

  Having some challengable piggybacks out there (see above), last of which started at `last_exit_height`, do:

  ```
  :ok = ByzantineEvents.watcher_synchronize(root_chain_height: last_exit_height)
  to_challenge = timeit ByzantineEvents.get_byzantine_events("invalid_piggyback")
  challenge_responses = timeit ByzantineEvents.get_many_non_canonical_proofs(to_challenge)
  ```
  """
  @spec get_many_piggyback_challenges(list({Transaction.txbytes(), list(non_neg_integer), list(non_neg_integer)})) ::
          list(map())
  def get_many_piggyback_challenges(piggybacks) do
    piggybacks
    |> Enum.shuffle()
    |> Enum.flat_map(fn {tx, inputs, outputs} ->
      input_challenges = Enum.map(inputs, &WatcherClient.get_input_challenge_data(tx, &1))
      output_challenges = Enum.map(outputs, &WatcherClient.get_output_challenge_data(tx, &1))
      Enum.concat(input_challenges, output_challenges)
    end)
    |> only_successes()
  end

  @doc """
  For given challenges (maps received from the Watcher) challenge all the invalid exits in the root chain contract.

  Will use `challenger_address`, which can be any well-funded address.

  Will send out all transactions concurrently, fail if any of them fails and block till the last gets mined. Returns
  the receipt of the last transaction sent out.
  """
  @spec challenge_many_piggybacks(list(map), OMG.Crypto.address_t()) :: {:ok, map()} | {:error, any()}
  def challenge_many_piggybacks(challenge_responses, challenger_address) do
    map_contract_transaction(challenge_responses, fn challenge ->
      if Map.has_key?(challenge, :in_flight_proof),
        do:
          Support.RootChainHelper.challenge_in_flight_exit_output_spent(
            challenge.in_flight_txbytes,
            challenge.in_flight_output_pos,
            challenge.in_flight_proof,
            challenge.spending_txbytes,
            challenge.spending_input_index,
            challenge.spending_sig,
            challenger_address
          ),
        else:
          Support.RootChainHelper.challenge_in_flight_exit_input_spent(
            challenge.in_flight_txbytes,
            challenge.in_flight_input_index,
            challenge.spending_txbytes,
            challenge.spending_input_index,
            challenge.spending_sig,
            challenge.input_tx,
            challenge.input_utxo_pos,
            challenger_address
          )
    end)
  end

  @doc """
  Fetches utxo positions for a given user's address.

  ## Usage

  On top of the generic setup (see above) do:

  ```
  utxo_positions = timeit ByzantineEvents.get_exitable_utxos(alice.addr)
  ```

  Options:
    - :take - if not nil, will limit to this many results
  """
  @spec get_exitable_utxos(OMG.Crypto.address_t(), keyword()) :: list(pos_integer())
  def get_exitable_utxos(addr, opts \\ []) when is_binary(addr) do
    {:ok, utxos} = WatcherClient.get_exitable_utxos(addr)
    utxo_positions = Enum.map(utxos, & &1.utxo_pos)

    if opts[:take], do: Enum.take(utxo_positions, opts[:take]), else: utxo_positions
  end

  @doc """
  Blocks the caller until the watcher configured reports to be fully synced up (both child chain blocks and eth events)

  Options:
    - :root_chain_height - if not `nil`, in addition to synchronizing to current top mined child chain block, it will
      sync up till all the Watcher's services report at at least this Ethereum height
  """
  @spec watcher_synchronize(keyword()) :: :ok
  def watcher_synchronize(opts \\ []) do
    root_chain_height = Keyword.get(opts, :root_chain_height, nil)

    _ = Logger.info("Waiting for the watcher to synchronize")
    :ok = WaitFor.ok(fn -> watcher_synchronized?(root_chain_height) end, :infinity)
    # NOTE: allowing some more time for the dust to settle on the synced Watcher
    # otherwise some of the freshest UTXOs to exit will appear as missing on the Watcher
    # related issue to remove this `sleep` and fix properly is https://github.com/omisego/elixir-omg/issues/1031
    Process.sleep(2000)
    _ = Logger.info("Watcher synchronized")
  end

  @doc """
  Gets all the byzantine events from the Watcher
  """
  @spec get_byzantine_events() :: list(map())
  def get_byzantine_events() do
    {:ok, status_response} = WatcherClient.get_status()
    status_response[:byzantine_events]
  end

  @doc """
  Gets byzantine events of a particular flavor from the Watcher
  """
  @spec get_byzantine_events(String.t()) :: list(map())
  def get_byzantine_events(event_name) do
    get_byzantine_events()
    |> Enum.filter(&(&1["event"] == event_name))
    |> postprocess_byzantine_events(event_name)
  end

  defp postprocess_byzantine_events(events, "invalid_exit"), do: Enum.map(events, & &1["details"]["utxo_pos"])
  # FIXME: the decode should be elsewhere I think. Or at least nicen/refactor all the clauses!!! this is a mess
  defp postprocess_byzantine_events(events, "non_canonical_ife"),
    do:
      Enum.map(events, & &1["details"]["txbytes"])
      |> Enum.map(&Encoding.from_hex/1)
      |> Enum.map(fn {:ok, result} -> result end)

  defp postprocess_byzantine_events(events, "invalid_ife_challenge"),
    do:
      Enum.map(events, & &1["details"]["txbytes"])
      |> Enum.map(&Encoding.from_hex/1)
      |> Enum.map(fn {:ok, result} -> result end)

  defp postprocess_byzantine_events(events, "piggyback_available"),
    do:
      Enum.map(
        events,
        &{&1["details"]["txbytes"], &1["details"]["available_inputs"], &1["details"]["available_outputs"]}
      )
      |> Enum.map(fn {tx, inputs, outputs} ->
        {Encoding.from_hex(tx), Enum.map(inputs, & &1["index"]), Enum.map(outputs, & &1["index"])}
      end)
      |> Enum.map(fn {{:ok, result}, inputs, outputs} -> {result, inputs, outputs} end)

  defp postprocess_byzantine_events(events, "invalid_piggyback"),
    do:
      Enum.map(events, &{&1["details"]["txbytes"], &1["details"]["inputs"], &1["details"]["outputs"]})
      |> Enum.map(fn {tx, inputs, outputs} -> {Encoding.from_hex(tx), inputs, outputs} end)
      |> Enum.map(fn {{:ok, result}, inputs, outputs} -> {result, inputs, outputs} end)

  defp only_successes(responses), do: Enum.map(responses, fn {:ok, response} -> response end)

  # this allows one to map a contract-transacting function over a collection nicely.
  # It initiates all the transactions concurrently. Then it waits on all of them to mine successfully.
  # Returns the last receipt result, so you can synchronize on the block number returned (and the entire bundle of txs)
  defp map_contract_transaction(enumerable, transaction_function) do
    transaction_function_results = Enum.map(enumerable, transaction_function)
    {:ok, supervisor} = Task.Supervisor.start_link(name: OMG.Performance.ByzantineEvents.TaskSupervisor)

    try do
      Task.Supervisor.async_stream_nolink(
        supervisor,
        transaction_function_results,
        &Support.DevHelper.transact_sync!(&1, timeout: :infinity),
        timeout: :infinity,
        # NOTE: infinity doesn't work for `:max_concurrency`, hence the large number
        max_concurrency: 10_000
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> List.last()
    rescue
      reason ->
        _ = Logger.warn("Some transactions might have failed: #{inspect(reason)}, stopping Task.Supervisor")
        reason
    after
      :ok = Supervisor.stop(supervisor)
    end
  end

  # This function is prepared to be called in `WaitFor.ok`.
  # It repeatedly ask for Watcher's `/status.get` until Watcher consume mined block
  defp watcher_synchronized?(root_chain_height) do
    {:ok, status} = WatcherClient.get_status()

    with true <- watcher_synchronized_to_mined_block?(status),
         true <- root_chain_synced?(root_chain_height, status) do
      :ok
    else
      _ -> :repeat
    end
  end

  defp root_chain_synced?(nil, _), do: true

  defp root_chain_synced?(root_chain_height, status) do
    status
    |> Access.get(:services_synced_heights)
    |> Enum.all?(&(&1["height"] >= root_chain_height))
  end

  defp watcher_synchronized_to_mined_block?(%{
         last_mined_child_block_number: last_mined_child_block_number,
         last_validated_child_block_number: last_validated_child_block_number
       })
       when last_mined_child_block_number == last_validated_child_block_number and
              last_mined_child_block_number > 0 do
    _ = Logger.debug("Synced to blknum: #{last_validated_child_block_number}")
    true
  end

  defp watcher_synchronized_to_mined_block?(_), do: false
end
