# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Watcher.ExitProcessor.InFlightExitInfo do
  @moduledoc """
  Represents the bulk of information about a tracked in-flight exit.

  Internal stuff of `OMG.Watcher.ExitProcessor`
  """

  alias OMG.State.Transaction
  alias OMG.Utxo

  require Utxo
  require Transaction
  require Transaction.Payment

  @max_inputs Transaction.Payment.max_inputs()
  @max_outputs Transaction.Payment.max_outputs()
  @inputs_index_range 0..(@max_inputs - 1)
  @outputs_index_range 0..(@max_outputs - 1)

  @type combined_index_t() :: {:input, 0..unquote(@max_inputs - 1)} | {:output, 0..unquote(@max_outputs - 1)}

  # TODO: divide into inputs and outputs: prevent contract's implementation from leaking into watcher
  # https://github.com/omgnetwork/elixir-omg/pull/361#discussion_r247926222

  @enforce_keys [
    :tx,
    :timestamp,
    :contract_id,
    :eth_height,
    :is_active
  ]

  defstruct [
    :tx,
    :contract_tx_pos,
    :tx_seen_in_blocks_at,
    :timestamp,
    :contract_id,
    :oldest_competitor,
    :eth_height,
    :input_txs,
    :input_utxos_pos,
    :relevant_from_blknum,
    # piggybacking & finalization
    exit_map: Map.new(),
    is_canonical: true,
    is_active: true
  ]

  @type blknum() :: pos_integer()
  @type tx_index() :: non_neg_integer()

  @type ife_contract_id() :: <<_::192>>

  @type exit_map_t() :: %{
          {:input | :output, non_neg_integer()} => %{
            is_piggybacked: boolean(),
            is_finalized: boolean(),
            is_challenged: boolean()
          }
        }

  @type t :: %__MODULE__{
          tx: Transaction.Signed.t(),
          # if not nil, position was proven in contract
          contract_tx_pos: Utxo.Position.t() | nil,
          # nil value means that it was not included
          # OR we haven't processed it yet
          # OR we have found and filled this data, but haven't persisted it later
          tx_seen_in_blocks_at: {Utxo.Position.t(), inclusion_proof :: binary()} | nil,
          timestamp: non_neg_integer(),
          contract_id: ife_contract_id(),
          # includes a special value denoting "age" of a non-included transaction being a competitor
          oldest_competitor: Utxo.Position.t() | :no_position | nil,
          eth_height: pos_integer(),
          input_txs: list(Transaction.Protocol.t()),
          input_utxos_pos: list(Utxo.Position.t()),
          relevant_from_blknum: pos_integer(),
          exit_map: exit_map_t(),
          is_canonical: boolean(),
          is_active: boolean()
        }

  @doc """
  Creates a new instance of the key-value pair for the respective `InFlightExitInfo`, from the Ethereum event map
  """
  @spec new_kv(map(), {tuple(), non_neg_integer()}) :: t()
  def new_kv(event, {contract_status, contract_ife_id}) do
    %{
      eth_height: eth_height,
      in_flight_tx: tx_bytes,
      in_flight_tx_sigs: signatures,
      # input_txs: input_txs,
      input_utxos_pos: input_utxos_pos
    } = event

    do_new(tx_bytes, signatures, contract_status,
      contract_id: <<contract_ife_id::192>>,
      eth_height: eth_height,
      # input_txs: input_txs,
      input_utxos_pos: Enum.map(input_utxos_pos, &Utxo.Position.decode!/1)
    )
  end

  defp do_new(tx_bytes, tx_signatures, contract_status, fields) do
    {timestamp, is_active} = parse_contract_in_flight_exit_status(contract_status)

    with {:ok, tx} <- prepare_tx(tx_bytes, tx_signatures) do
      # NOTE: in case of using output_id as the input pointer, getting the youngest will be entirely different
      Utxo.position(youngest_input_blknum, _, _) =
        tx
        |> Transaction.get_inputs()
        |> Enum.sort_by(&Utxo.Position.encode/1, &>=/2)
        |> hd()

      fields =
        fields
        |> Keyword.put_new(:tx, tx)
        |> Keyword.put_new(:is_active, is_active)
        |> Keyword.put_new(:relevant_from_blknum, youngest_input_blknum)
        |> Keyword.put_new(:timestamp, timestamp)

      {Transaction.raw_txhash(tx), struct!(__MODULE__, fields)}
    end
  end

  defp parse_contract_in_flight_exit_status({_, timestamp, _, _, _, _, _}), do: {timestamp, timestamp != 0}

  defp prepare_tx(tx_bytes, tx_signatures) do
    with {:ok, raw_tx} <- Transaction.decode(tx_bytes) do
      tx = %Transaction.Signed{raw_tx: raw_tx, sigs: tx_signatures}
      {:ok, tx}
    end
  end

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def make_db_update({ife_hash,
       %__MODULE__{
         tx: %Transaction.Signed{} = tx,
         contract_tx_pos: tx_pos,
         timestamp: timestamp,
         contract_id: contract_id,
         oldest_competitor: oldest_competitor,
         eth_height: eth_height,
         # input_txs: input_txs,
         input_utxos_pos: input_utxos_pos,
         relevant_from_blknum: relevant_from_blknum,
         exit_map: exit_map,
         is_canonical: is_canonical,
         is_active: is_active
       }})
      # and is_list(input_txs)
      when is_binary(contract_id) and
             is_integer(timestamp) and is_integer(eth_height) and is_list(input_utxos_pos) and
             is_integer(relevant_from_blknum) and
             is_map(exit_map) and is_boolean(is_canonical) and is_boolean(is_active) do
    :ok = assert_utxo_pos_type(tx_pos)
    :ok = assert_utxo_pos_type(oldest_competitor)
    # mapping is used in case of changes in data structure
    value = %{
      tx: to_db_value(tx),
      tx_pos: tx_pos,
      timestamp: timestamp,
      contract_id: contract_id,
      oldest_competitor: oldest_competitor,
      eth_height: eth_height,
      # input_txs: input_txs,
      input_utxos_pos: input_utxos_pos,
      relevant_from_blknum: relevant_from_blknum,
      exit_map: exit_map,
      is_canonical: is_canonical,
      is_active: is_active
    }

    {:put, :in_flight_exit_info, {ife_hash, value}}
  end

  @doc """
  Returns all input utxos for given in-flight exits
  """
  @spec get_input_utxos(list(t())) :: list(Utxo.Position.t())
  def get_input_utxos(in_flight_exits) do
    in_flight_exits
    |> Enum.map(& &1.input_utxos_pos)
    |> List.flatten()
  end

  defp assert_utxo_pos_type(Utxo.position(blknum, txindex, oindex))
       when is_integer(blknum) and is_integer(txindex) and is_integer(oindex),
       do: :ok

  defp assert_utxo_pos_type(nil), do: :ok

  # a special value denoting position ("age") of a non-included transaction is ok too
  defp assert_utxo_pos_type(:no_position), do: :ok

  def from_db_kv({ife_hash, fields}) do
    # TODO: this got really horrible. Instead of tidying up/maintaining maybe go `Ecto` and use `Ecto.x` facilities
    #       on this here and elsewhere
    assert_types(fields, [:tx_pos, :oldest_competitor], fn value -> :ok = assert_utxo_pos_type(value) end)
    assert_types(fields, [:tx, :exit_map], fn value -> true = is_map(value) end)
    assert_types(fields, [:contract_id], fn value -> true = is_binary(value) end)
    assert_types(fields, [:timestamp, :eth_height, :relevant_from_blknum], fn value -> true = is_integer(value) end)
    # assert_types(fields, [:input_txs, :input_utxos_pos], fn value -> true = is_list(value) end)
    assert_types(fields, [:is_canonical, :is_active], fn value -> true = is_boolean(value) end)
    # mapping is used in case of changes in data structure
    ife_map = %{
      tx: from_db_signed_tx(fields[:tx]),
      contract_tx_pos: fields[:tx_pos],
      timestamp: fields[:timestamp],
      contract_id: fields[:contract_id],
      oldest_competitor: fields[:oldest_competitor],
      eth_height: fields[:eth_height],
      # input_txs: fields[:input_txs],
      input_utxos_pos: fields[:input_utxos_pos],
      relevant_from_blknum: fields[:relevant_from_blknum],
      exit_map: fields[:exit_map],
      is_canonical: fields[:is_canonical],
      is_active: fields[:is_active]
    }

    {ife_hash, struct!(__MODULE__, ife_map)}
  end

  defp assert_types(fields, keys, assertion) do
    fields
    |> Map.take(keys)
    |> Map.values()
    |> Enum.each(assertion)
  end

  # NOTE: non-private because `CompetitorInfo` holds `Transaction.Signed` objects too
  def from_db_signed_tx(%{raw_tx: raw_tx_map, sigs: sigs}) when is_map(raw_tx_map) and is_list(sigs) do
    value = %{raw_tx: from_db_raw_tx(raw_tx_map), sigs: sigs}
    struct!(Transaction.Signed, value)
  end

  def from_db_raw_tx(%{tx_type: tx_type, inputs: inputs, outputs: outputs, metadata: metadata})
      when is_list(inputs) and is_list(outputs) and Transaction.is_metadata(metadata) do
    value = %{tx_type: tx_type, inputs: inputs, outputs: outputs, metadata: metadata}
    struct!(Transaction.Payment, value)
  end

  def to_db_value(%Transaction.Signed{raw_tx: raw_tx, sigs: sigs}) when is_list(sigs) do
    %{raw_tx: to_db_value(raw_tx), sigs: sigs}
  end

  def to_db_value(%Transaction.Payment{tx_type: tx_type, inputs: inputs, outputs: outputs, metadata: metadata})
      when is_list(inputs) and is_list(outputs) and Transaction.is_metadata(metadata) do
    %{tx_type: tx_type, inputs: inputs, outputs: outputs, metadata: metadata}
  end

  @spec piggyback(t(), combined_index_t()) :: t() | {:error, :non_existent_exit | :cannot_piggyback}
  def piggyback(ife, index)

  def piggyback(%__MODULE__{exit_map: exit_map} = ife, combined_index) when is_tuple(combined_index) do
    with exit <- exit_map_get(exit_map, combined_index),
         {:ok, updated_exit} <- piggyback_exit(exit) do
      %{ife | exit_map: Map.put(exit_map, combined_index, updated_exit)}
    end
  end

  def piggyback(%__MODULE__{}, _), do: {:error, :non_existent_exit}

  defp piggyback_exit(%{is_piggybacked: false, is_finalized: false, is_challenged: false} = exit_map_entry),
    do: {:ok, %{exit_map_entry | is_piggybacked: true}}

  defp piggyback_exit(_), do: {:error, :cannot_piggyback}

  @spec challenge(t(), non_neg_integer()) :: t() | {:error, :competitor_too_young}
  def challenge(ife, competitor_position)

  def challenge(%__MODULE__{oldest_competitor: nil} = ife, competitor_position) do
    %{ife | is_canonical: false, oldest_competitor: decode_position_possibly_exceeding(competitor_position)}
  end

  def challenge(%__MODULE__{oldest_competitor: current_oldest} = ife, competitor_position) do
    with decoded_competitor_pos <- Utxo.Position.decode!(competitor_position),
         true <- is_older?(decoded_competitor_pos, current_oldest) do
      %{ife | is_canonical: false, oldest_competitor: decoded_competitor_pos}
    else
      _ -> {:error, :competitor_too_young}
    end
  end

  @spec challenge_piggyback(t(), combined_index_t()) :: t()
  def challenge_piggyback(%__MODULE__{exit_map: exit_map} = ife, combined_index) when is_tuple(combined_index) do
    %{is_piggybacked: true, is_finalized: false, is_challenged: false} =
      exit_map_entry = exit_map_get(exit_map, combined_index)

    %{ife | exit_map: Map.replace!(exit_map, combined_index, %{exit_map_entry | is_challenged: true})}
  end

  @spec respond_to_challenge(t(), Utxo.Position.t()) ::
          t() | {:error, :responded_with_too_young_tx | :cannot_respond}
  def respond_to_challenge(ife, tx_position)

  def respond_to_challenge(%__MODULE__{oldest_competitor: current_oldest} = ife, tx_position) do
    decoded = Utxo.Position.decode!(tx_position)

    if is_nil(current_oldest) or is_older?(decoded, current_oldest) do
      %{ife | oldest_competitor: decoded, is_canonical: true, contract_tx_pos: decoded}
    else
      {:error, :responded_with_too_young_tx}
    end
  end

  def respond_to_challenge(%__MODULE__{}, _), do: {:error, :cannot_respond}

  @spec finalize(t(), combined_index_t()) :: {:ok, t()} | :unknown_output_index
  def finalize(%__MODULE__{exit_map: exit_map} = ife, combined_index) when is_tuple(combined_index) do
    case exit_map_get(exit_map, combined_index) do
      nil ->
        :unknown_output_index

      output_exit ->
        output_exit = %{output_exit | is_finalized: true}
        exit_map = Map.put(exit_map, combined_index, output_exit)
        ife = %{ife | exit_map: exit_map}

        is_active =
          exit_map
          |> Map.keys()
          |> Enum.any?(&is_active?(ife, &1))

        ife = %{ife | is_active: is_active}
        {:ok, ife}
    end
  end

  @spec get_active_output_piggybacks_positions(t()) :: [Utxo.Position.t()]
  def get_active_output_piggybacks_positions(%__MODULE__{tx_seen_in_blocks_at: nil}), do: []

  def get_active_output_piggybacks_positions(
        %__MODULE__{tx_seen_in_blocks_at: {Utxo.position(blknum, txindex, _), _}} = ife
      ) do
    @outputs_index_range
    |> Enum.filter(&is_unchallenged?(ife, {:output, &1}))
    |> Enum.map(&Utxo.position(blknum, txindex, &1))
  end

  def unchallenged_piggybacks_by_ife(%__MODULE__{tx: tx} = ife, :input) do
    indexed_piggybacked_inputs =
      tx
      |> Transaction.get_inputs()
      |> Enum.with_index()
      |> Enum.filter(fn {_input, index} -> is_unchallenged?(ife, {:input, index}) end)

    {ife, indexed_piggybacked_inputs}
  end

  def unchallenged_piggybacks_by_ife(%__MODULE__{} = ife, :output) do
    indexed_piggybacked_outputs =
      ife
      |> get_active_output_piggybacks_positions()
      |> Enum.map(&index_output_position/1)

    {ife, indexed_piggybacked_outputs}
  end

  defp index_output_position(position) do
    Utxo.position(_, _, oindex) = position
    {position, oindex}
  end

  def actively_piggybacked_inputs(ife) do
    @inputs_index_range
    |> Enum.filter(&is_active?(ife, {:input, &1}))
  end

  def actively_piggybacked_outputs(ife) do
    @outputs_index_range
    |> Enum.filter(&is_active?(ife, {:output, &1}))
  end

  @spec is_active?(t(), combined_index_t()) :: boolean()
  def is_active?(%__MODULE__{} = ife, combined_index) do
    is_piggybacked?(ife, combined_index) and
      !is_finalized?(ife, combined_index) and
      !is_challenged?(ife, combined_index)
  end

  @spec is_unchallenged?(t(), combined_index_t()) :: boolean()
  def is_unchallenged?(%__MODULE__{} = ife, combined_index) do
    is_piggybacked?(ife, combined_index) and
      !is_challenged?(ife, combined_index)
  end

  def activate(%__MODULE__{} = ife) do
    %{ife | is_active: true}
  end

  def should_be_seeked_in_blocks?(%__MODULE__{} = ife),
    do: ife.is_active && ife.tx_seen_in_blocks_at == nil

  @doc """
  First, it determines if it is challenged at all - if it isn't returns false.
  Second, If the tx hasn't been seen at all then it will be false
  If it is challenged (hence non-canonical) and seen it will figure out if the IFE tx has been seen in an older than
  oldest competitor's position.
  """
  @spec is_invalidly_challenged?(t()) :: boolean()
  def is_invalidly_challenged?(%__MODULE__{is_canonical: true}), do: false
  def is_invalidly_challenged?(%__MODULE__{tx_seen_in_blocks_at: nil}), do: false

  def is_invalidly_challenged?(state) do
    {Utxo.position(_, _, _) = seen_in_pos, _proof} = state.tx_seen_in_blocks_at
    is_older?(seen_in_pos, state.oldest_competitor)
  end

  @doc """
  Converts integer to contract's in-flight exit id
  """
  @spec to_contract_id(non_neg_integer) :: <<_::192>>
  def to_contract_id(id), do: <<id::192>>

  @doc """
  Checks if the competitor being seen at `competitor_pos` (`nil` if unseen) is viable to challenge with, considering the
  current state of the IFE - that is, only if it is older than IFE tx's inclusion and other competitors
  """
  @spec is_viable_competitor?(t(), Utxo.Position.t() | nil) :: boolean()
  def is_viable_competitor?(
        %__MODULE__{tx_seen_in_blocks_at: nil, oldest_competitor: oldest_competitor_pos},
        competitor_pos
      ),
      do: do_is_viable_competitor?(nil, oldest_competitor_pos, competitor_pos)

  def is_viable_competitor?(
        %__MODULE__{tx_seen_in_blocks_at: {seen_at_pos, _proof}, oldest_competitor: oldest_competitor_pos},
        competitor_pos
      ),
      do: do_is_viable_competitor?(seen_at_pos, oldest_competitor_pos, competitor_pos)

  def is_relevant?(%__MODULE__{relevant_from_blknum: relevant_from_blknum}, blknum_now),
    do: relevant_from_blknum < blknum_now

  @spec is_piggybacked?(t(), combined_index_t()) :: boolean()
  def is_piggybacked?(%__MODULE__{exit_map: map}, combined_index) when is_tuple(combined_index) do
    if exit = exit_map_get(map, combined_index) do
      Map.get(exit, :is_piggybacked, false)
    else
      false
    end
  end

  @spec is_finalized?(t(), combined_index_t()) :: boolean()
  defp is_finalized?(%__MODULE__{exit_map: map}, combined_index) do
    if exit = exit_map_get(map, combined_index) do
      Map.get(exit, :is_finalized, false)
    else
      false
    end
  end

  @spec is_challenged?(t(), combined_index_t()) :: boolean()
  defp is_challenged?(%__MODULE__{exit_map: map}, combined_index) do
    if exit = exit_map_get(map, combined_index) do
      Map.get(exit, :is_challenged, false)
    else
      false
    end
  end

  # there's nothing with any position, so there's nothing older than competitor, so it's good to challenge with
  defp do_is_viable_competitor?(nil, nil, _competitor_pos), do: true
  # there's something with position and the competitor doesn't have any - not good to challenge with
  defp do_is_viable_competitor?(_seen_at_pos, _oldest_pos, nil), do: false
  # there already is a competitor reported in the contract, if the competitor is older then good to challenge with
  defp do_is_viable_competitor?(nil, oldest_pos, competitor_pos), do: is_older?(competitor_pos, oldest_pos)
  # this IFE tx has been already seen at some position, if the competitor is older then good to challenge with
  defp do_is_viable_competitor?(seen_at_pos, nil, competitor_pos), do: is_older?(competitor_pos, seen_at_pos)
  # the competitor must be older than anything else to be good to challenge with
  defp do_is_viable_competitor?(seen_at_pos, oldest_pos, competitor_pos),
    do: is_older?(competitor_pos, seen_at_pos) and is_older?(competitor_pos, oldest_pos)

  # no position is older than any real position
  defp is_older?(Utxo.position(_, _, _), :no_position), do: true
  # no position is younger than any real position
  defp is_older?(:no_position, Utxo.position(_, _, _)), do: false
  # for real positions, the smaller it is the older it is
  defp is_older?(Utxo.position(tx1_blknum, tx1_index, _), Utxo.position(tx2_blknum, tx2_index, _)),
    do: tx1_blknum < tx2_blknum or (tx1_blknum == tx2_blknum and tx1_index < tx2_index)

  # to cater for utxo positions coming from the contract, that represent non-included transactions
  defp decode_position_possibly_exceeding(encoded_position) do
    case Utxo.Position.decode(encoded_position) do
      {:ok, Utxo.position(_, _, _) = decoded} -> decoded
      # The position was huge so it denoted a non-included transaction.
      # Use a special value denoting "age" of a non-included transaction
      {:error, :encoded_utxo_position_too_low} -> :no_position
    end
  end

  @spec exit_map_get(exit_map_t(), combined_index_t()) :: %{
          is_piggybacked: boolean(),
          is_finalized: boolean(),
          is_challenged: boolean()
        }
  defp exit_map_get(exit_map, {type, index} = combined_index)
       when (type == :input and index < @max_inputs) or (type == :output and index < @max_outputs),
       do: Map.get(exit_map, combined_index, %{is_piggybacked: false, is_finalized: false, is_challenged: false})
end
