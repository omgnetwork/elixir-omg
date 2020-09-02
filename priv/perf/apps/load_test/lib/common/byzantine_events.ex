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

defmodule LoadTest.Common.ByzantineEvents do
  @moduledoc """
  OMG network child chain server byzantine event test entrypoint. Runs performance byzantine tests.

  ## Usage

  To setup, once you have your Ethereum node and a child chain running, from a configured `iex -S mix run --no-start`
  shell do:

  ```
  use LoadTest.Performance

  Performance.init()
  spenders = Generators.generate_users(2)
  ```

  You probably want to prefill the child chain with transactions, see `OMG.Performance.ExtendedPerftest` or just:
  ```
  LoadTest.Common.ExtendedPerftest.start(10_000, 16, 75, randomized: false)
  ```
  (`randomized: false` is useful to test massive honest-standard-exiting, since it will create many unspent UTXOs for
  each of the spenders)
  """

  require Logger

  alias ExPlasma.Encoding
  alias LoadTest.ChildChain.Exit
  alias LoadTest.Ethereum
  alias LoadTest.Ethereum.Sync

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

  NOTE this uses unspent UTXOs creating valid exits for `alice`. For invalid exits do

  ```
  utxo_positions = Generators.stream_utxo_positions(owned_by: alice.addr, take: 20)
  ```
  """
  @spec get_many_standard_exits(list(pos_integer())) :: list(map())
  def get_many_standard_exits(exit_positions) do
    result =
      exit_positions
      |> Enum.shuffle()
      |> Enum.map(fn encoded_position ->
        client = LoadTest.Connection.WatcherSecurity.client()
        params = %WatcherSecurityCriticalAPI.Model.UtxoPositionBodySchema1{utxo_pos: encoded_position}
        response_result = WatcherSecurityCriticalAPI.Api.UTXO.utxo_get_exit_data(client, params)

        case response_result do
          {:ok, response} -> {:ok, Jason.decode!(response.body)["data"]}
          other -> other
        end
      end)
      |> only_successes()

    result
  end

  @doc """
  For given standard exit datas (maps received from the Watcher) start all the exits in the root chain contract.

  Will use `owner_address` to start the exits so this address must own all the supplied UTXOs to exit.

  Will send out all transactions concurrently, fail if any of them fails and block till the last gets mined. Returns
  the receipt of the last transaction sent out.
  """
  @spec start_many_exits(list(map), binary()) :: {:ok, map()} | {:error, any()}
  def start_many_exits(exit_datas, owner_address) do
    map_contract_transaction(exit_datas, fn composed_exit ->
      txbytes = Encoding.to_binary(composed_exit["txbytes"])
      proof = Encoding.to_binary(composed_exit["proof"])

      Exit.start_exit(
        composed_exit["utxo_pos"],
        txbytes,
        proof,
        owner_address
      )
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
    |> Enum.map(fn position ->
      client = LoadTest.Connection.WatcherSecurity.client()
      params = %WatcherSecurityCriticalAPI.Model.UtxoPositionBodySchema{utxo_pos: position}
      response_result = WatcherSecurityCriticalAPI.Api.UTXO.utxo_get_challenge_data(client, params)

      case response_result do
        {:ok, response} -> {:ok, Jason.decode!(response.body)["data"]}
        error -> error
      end
    end)
    |> only_successes()
  end

  @doc """
  For given challenges (maps received from the Watcher) challenge all the invalid exits in the root chain contract.

  Will use `challenger_address`, which can be any well-funded address.

  Will send out all transactions concurrently, fail if any of them fails and block till the last gets mined. Returns
  the receipt of the last transaction sent out.
  """
  @spec challenge_many_exits(list(map), binary()) :: {:ok, map()} | {:error, any()}
  def challenge_many_exits(challenge_responses, challenger_address) do
    map_contract_transaction(challenge_responses, fn challenge ->
      Exit.challenge_exit(
        challenge["exit_id"],
        Encoding.to_binary(challenge["exiting_tx"]),
        Encoding.to_binary(challenge["txbytes"]),
        challenge["input_index"],
        Encoding.to_binary(challenge["sig"]),
        challenger_address
      )
    end)
  end

  @doc """
  Fetches utxo positions for a given user's address.

  ## Usage

  On top of the generic setup (see above) do:

  ```
  timeit ByzantineEvents.get_exitable_utxos(alice.addr)
  ```

  Options:
    - :take - if not nil, will limit to this many results
  """
  @spec get_exitable_utxos(binary(), keyword()) :: list(pos_integer())
  def get_exitable_utxos(addr, opts \\ []) when is_binary(addr) do
    client = LoadTest.Connection.WatcherSecurity.client()
    params = %WatcherInfoAPI.Model.AddressBodySchema1{address: Encoding.to_hex(addr)}
    {:ok, utxos_response} = WatcherSecurityCriticalAPI.Api.Account.account_get_exitable_utxos(client, params)
    utxos = Jason.decode!(utxos_response.body)["data"]

    utxo_positions = Enum.map(utxos, & &1["utxo_pos"])

    result = if opts[:take], do: Enum.take(utxo_positions, opts[:take]), else: utxo_positions

    result
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
    service = Keyword.get(opts, :service, nil)

    _ = Logger.info("Waiting for the watcher to synchronize")

    :ok = Sync.repeat_until_success(fn -> watcher_synchronized?(root_chain_height, service) end, 500_000)
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
    {:ok, status_response} =
      WatcherSecurityCriticalAPI.Api.Status.status_get(LoadTest.Connection.WatcherSecurity.client())

    Jason.decode!(status_response.body)["data"]["byzantine_events"]
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

  defp only_successes(responses), do: Enum.map(responses, fn {:ok, response} -> response end)

  # this allows one to map a contract-transacting function over a collection nicely.
  # It initiates all the transactions concurrently. Then it waits on all of them to mine successfully.
  # Returns the last receipt result, so you can synchronize on the block number returned (and the entire bundle of txs)
  defp map_contract_transaction(enumberable, transaction_function) do
    enumberable
    |> Enum.map(transaction_function)
    |> Task.async_stream(&Ethereum.transact_sync(&1, 200_000),
      timeout: :infinity,
      max_concurrency: 10_000
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> List.last()
  end

  # This function is prepared to be called in `Sync`.
  # It repeatedly ask for Watcher's `/status.get` until Watcher consume mined block
  defp watcher_synchronized?(root_chain_height, service) do
    {:ok, status_response} =
      WatcherSecurityCriticalAPI.Api.Status.status_get(LoadTest.Connection.WatcherSecurity.client())

    status = Jason.decode!(status_response.body)["data"]

    with true <- watcher_synchronized_to_mined_block?(status),
         true <- root_chain_synced?(root_chain_height, status, service) do
      :ok
    else
      _ -> :repeat
    end
  end

  defp root_chain_synced?(nil, _, _), do: true

  defp root_chain_synced?(root_chain_height, status, nil) do
    status
    |> Map.get("services_synced_heights")
    |> Enum.reject(fn height ->
      service = height["service"]
      # these service heights are stuck on circle ci, but they work fine locally
      # I think ci machin is not powerful enough
      service == "block_getter" || service == "exit_finalizer" || service == "ife_exit_finalizer"
    end)
    |> Enum.all?(&(&1["height"] >= root_chain_height))
  end

  defp root_chain_synced?(root_chain_height, status, service) do
    heights = Map.get(status, "services_synced_heights")

    found_root_chain_height = Enum.find(heights, fn height -> height["service"] == service end)

    found_root_chain_height && found_root_chain_height["height"] >= root_chain_height
  end

  defp watcher_synchronized_to_mined_block?(%{
         "last_mined_child_block_number" => last_mined_child_block_number,
         "last_validated_child_block_number" => last_validated_child_block_number
       })
       when last_mined_child_block_number == last_validated_child_block_number and
              last_mined_child_block_number > 0 do
    _ = Logger.debug("Synced to blknum: #{last_validated_child_block_number}")
    true
  end

  defp watcher_synchronized_to_mined_block?(_params) do
    :not_synchronized
  end
end
