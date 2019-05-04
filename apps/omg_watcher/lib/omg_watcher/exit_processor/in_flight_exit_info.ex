# Copyright 2018 OmiseGO Pte Ltd
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

  @max_inputs Transaction.max_inputs()

  # TODO: divide into inputs and outputs: prevent contract's implementation from leaking into watcher
  # https://github.com/omisego/elixir-omg/pull/361#discussion_r247926222
  @exit_map_index_range Range.new(0, @max_inputs * 2 - 1)

  @inputs_index_range Range.new(0, @max_inputs - 1)
  @outputs_index_range Range.new(@max_inputs, @max_inputs * 2 - 1)

  @max_number_of_inputs Enum.count(@inputs_index_range)

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
    # piggybacking
    exit_map:
      @exit_map_index_range
      |> Enum.map(&{&1, %{is_piggybacked: false, is_finalized: false}})
      |> Map.new(),
    is_canonical: true,
    is_active: true
  ]

  @type blknum() :: pos_integer()
  @type tx_index() :: non_neg_integer()

  @type ife_contract_id() :: <<_::192>>

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
          oldest_competitor: Utxo.Position.t() | nil,
          eth_height: pos_integer(),
          exit_map: %{
            non_neg_integer() => %{
              is_piggybacked: boolean(),
              is_finalized: boolean()
            }
          },
          is_canonical: boolean(),
          is_active: boolean()
        }

  def new_kv(
        %{eth_height: eth_height, call_data: %{in_flight_tx: tx_bytes, in_flight_tx_sigs: signatures}},
        {timestamp, contract_ife_id} = contract_status
      ) do
    do_new(tx_bytes, signatures, contract_status,
      contract_id: <<contract_ife_id::192>>,
      timestamp: timestamp,
      eth_height: eth_height
    )
  end

  defp do_new(tx_bytes, tx_signatures, contract_status, fields) do
    with {:ok, tx} <- prepare_tx(tx_bytes, tx_signatures) do
      fields =
        fields
        |> Keyword.put_new(:tx, tx)
        |> Keyword.put_new(:is_active, parse_contract_in_flight_exit_status(contract_status))

      {Transaction.raw_txhash(tx), struct!(__MODULE__, fields)}
    end
  end

  defp prepare_tx(tx_bytes, tx_signatures) do
    with {:ok, raw_tx} <- Transaction.decode(tx_bytes) do
      chopped_sigs = for <<chunk::size(65)-unit(8) <- tx_signatures>>, do: <<chunk::size(65)-unit(8)>>
      tx = %Transaction.Signed{raw_tx: raw_tx, sigs: chopped_sigs}
      {:ok, tx}
    end
  end

  defp parse_contract_in_flight_exit_status({timestamp, _contract_id}), do: timestamp != 0

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def make_db_update(
        {ife_hash,
         %__MODULE__{
           tx: %Transaction.Signed{} = tx,
           contract_tx_pos: tx_pos,
           timestamp: timestamp,
           contract_id: contract_id,
           oldest_competitor: oldest_competitor,
           eth_height: eth_height,
           exit_map: exit_map,
           is_canonical: is_canonical,
           is_active: is_active
         }}
      )
      when is_binary(contract_id) and
             is_integer(timestamp) and is_integer(eth_height) and is_map(exit_map) and
             is_boolean(is_canonical) and is_boolean(is_active) do
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
      exit_map: exit_map,
      is_canonical: is_canonical,
      is_active: is_active
    }

    {:put, :in_flight_exit_info, {ife_hash, value}}
  end

  defp assert_utxo_pos_type(Utxo.position(blknum, txindex, oindex))
       when is_integer(blknum) and is_integer(txindex) and is_integer(oindex),
       do: :ok

  defp assert_utxo_pos_type(nil), do: :ok

  def from_db_kv(
        {ife_hash,
         %{
           tx: signed_tx_map,
           tx_pos: tx_pos,
           timestamp: timestamp,
           contract_id: contract_id,
           oldest_competitor: oldest_competitor,
           eth_height: eth_height,
           exit_map: exit_map,
           is_canonical: is_canonical,
           is_active: is_active
         }}
      )
      when is_map(signed_tx_map) and is_binary(contract_id) and
             is_integer(timestamp) and is_integer(eth_height) and is_map(exit_map) and
             is_boolean(is_canonical) and is_boolean(is_active) do
    :ok = assert_utxo_pos_type(tx_pos)
    :ok = assert_utxo_pos_type(oldest_competitor)

    # mapping is used in case of changes in data structure
    ife_map = %{
      tx: from_db_signed_tx(signed_tx_map),
      contract_tx_pos: tx_pos,
      timestamp: timestamp,
      contract_id: contract_id,
      oldest_competitor: oldest_competitor,
      eth_height: eth_height,
      exit_map: exit_map,
      is_canonical: is_canonical,
      is_active: is_active
    }

    {ife_hash, struct!(__MODULE__, ife_map)}
  end

  # NOTE: the databases currently don't hold the `signed_tx_bytes` field, hence dropping this here and in the other fun.
  # NOTE: non-private because `CompetitorInfo` holds `Transaction.Signed` objects too
  def from_db_signed_tx(%{raw_tx: raw_tx_map, sigs: sigs}) when is_map(raw_tx_map) and is_list(sigs) do
    value = %{raw_tx: from_db_raw_tx(raw_tx_map), sigs: sigs}
    struct!(Transaction.Signed, value)
  end

  def from_db_raw_tx(%{inputs: inputs, outputs: outputs, metadata: metadata})
      when is_list(inputs) and is_list(outputs) and Transaction.is_metadata(metadata) do
    value = %{inputs: inputs, outputs: outputs, metadata: metadata}
    struct!(Transaction, value)
  end

  def to_db_value(%Transaction.Signed{raw_tx: raw_tx, sigs: sigs}) when is_list(sigs) do
    %{raw_tx: to_db_value(raw_tx), sigs: sigs}
  end

  def to_db_value(%Transaction{inputs: inputs, outputs: outputs, metadata: metadata})
      when is_list(inputs) and is_list(outputs) and Transaction.is_metadata(metadata) do
    %{inputs: inputs, outputs: outputs, metadata: metadata}
  end

  @spec piggyback(t(), non_neg_integer()) :: t() | {:error, :non_existent_exit | :cannot_piggyback}
  def piggyback(ife, index)

  def piggyback(%__MODULE__{exit_map: exit_map} = ife, index) when index in @exit_map_index_range do
    with exit <- Map.get(exit_map, index),
         {:ok, updated_exit} <- piggyback_exit(exit) do
      %{ife | exit_map: Map.put(exit_map, index, updated_exit)}
    end
  end

  def piggyback(%__MODULE__{}, _), do: {:error, :non_existent_exit}

  defp piggyback_exit(%{is_piggybacked: false, is_finalized: false}),
    do: {:ok, %{is_piggybacked: true, is_finalized: false}}

  defp piggyback_exit(_), do: {:error, :cannot_piggyback}

  @spec challenge(t(), non_neg_integer()) :: {:ok, t()} | {:error, :competitor_too_young}
  def challenge(ife, competitor_position)

  def challenge(%__MODULE__{oldest_competitor: nil} = ife, competitor_position),
    do: %{ife | is_canonical: false, oldest_competitor: Utxo.Position.decode!(competitor_position)}

  def challenge(%__MODULE__{oldest_competitor: current_oldest} = ife, competitor_position) do
    with decoded_competitor_pos <- Utxo.Position.decode!(competitor_position),
         true <- is_older?(decoded_competitor_pos, current_oldest) do
      %{ife | is_canonical: false, oldest_competitor: decoded_competitor_pos}
    else
      _ -> {:error, :competitor_too_young}
    end
  end

  def challenge_piggyback(%__MODULE__{exit_map: exit_map} = ife, index) when index in @exit_map_index_range do
    %{is_piggybacked: true, is_finalized: false} = Map.get(exit_map, index)
    %{ife | exit_map: Map.replace!(exit_map, index, %{is_piggybacked: false, is_finalized: false})}
  end

  @spec respond_to_challenge(t(), Utxo.Position.t()) ::
          {:ok, t()} | {:error, :responded_with_too_young_tx | :cannot_respond}
  def respond_to_challenge(ife, tx_position)

  def respond_to_challenge(%__MODULE__{oldest_competitor: nil, contract_tx_pos: nil} = ife, tx_position) do
    decoded = Utxo.Position.decode!(tx_position)
    {:ok, %{ife | oldest_competitor: decoded, is_canonical: true, contract_tx_pos: decoded}}
  end

  def respond_to_challenge(%__MODULE__{oldest_competitor: current_oldest, contract_tx_pos: nil} = ife, tx_position) do
    decoded = Utxo.Position.decode!(tx_position)

    if is_older?(decoded, current_oldest) do
      {:ok, %{ife | oldest_competitor: decoded, is_canonical: true, contract_tx_pos: decoded}}
    else
      {:error, :responded_with_too_young_tx}
    end
  end

  def respond_to_challenge(%__MODULE__{}, _), do: {:error, :cannot_respond}

  @spec finalize(t(), non_neg_integer()) :: {:ok, t()} | :unknown_output_index
  def finalize(%__MODULE__{exit_map: exit_map} = ife, output_index) do
    case Map.get(exit_map, output_index) do
      nil ->
        :unknown_output_index

      output_exit ->
        output_exit = %{output_exit | is_finalized: true}
        exit_map = Map.put(exit_map, output_index, output_exit)
        ife = %{ife | exit_map: exit_map}

        is_active =
          exit_map
          |> Map.keys()
          |> Enum.any?(fn output_index -> is_active?(ife, output_index) end)

        ife = %{ife | is_active: is_active}
        {:ok, ife}
    end
  end

  @spec get_piggybacked_outputs_positions(t()) :: [Utxo.Position.t()]
  def get_piggybacked_outputs_positions(%__MODULE__{tx_seen_in_blocks_at: nil}), do: []

  def get_piggybacked_outputs_positions(%__MODULE__{
        tx_seen_in_blocks_at: {txpos, _},
        exit_map: exit_map
      }) do
    {_, blknum, txindex, _} = txpos

    @outputs_index_range
    |> Enum.filter(&exit_map[&1].is_piggybacked)
    |> Enum.map(&Utxo.position(blknum, txindex, &1 - @max_number_of_inputs))
  end

  def is_piggybacked?(%__MODULE__{exit_map: map}, index) when is_integer(index) do
    with {:ok, exit} <- Map.fetch(map, index) do
      Map.get(exit, :is_piggybacked)
    else
      :error -> false
    end
  end

  def is_input_piggybacked?(%__MODULE__{} = ife, index) when is_integer(index) and index < @max_inputs do
    is_piggybacked?(ife, index)
  end

  def is_output_piggybacked?(%__MODULE__{} = ife, index) when is_integer(index) and index < @max_inputs do
    is_piggybacked?(ife, index + @max_inputs)
  end

  def piggybacked_inputs(ife) do
    @inputs_index_range
    |> Enum.filter(&is_piggybacked?(ife, &1))
  end

  def piggybacked_outputs(ife) do
    @outputs_index_range
    |> Enum.filter(&is_piggybacked?(ife, &1))
    |> Enum.map(&(&1 - @max_inputs))
  end

  def is_finalized?(%__MODULE__{exit_map: map}, index) do
    with {:ok, exit} <- Map.fetch(map, index) do
      Map.get(exit, :is_finalized)
    else
      :error -> false
    end
  end

  def is_active?(%__MODULE__{} = ife, index) do
    is_piggybacked?(ife, index) and !is_finalized?(ife, index)
  end

  def activate(%__MODULE__{} = ife) do
    %{ife | is_active: true}
  end

  def is_canonical?(%__MODULE__{is_canonical: value}), do: value

  defp is_older?(Utxo.position(tx1_blknum, tx1_index, _), Utxo.position(tx2_blknum, tx2_index, _)),
    do: tx1_blknum < tx2_blknum or (tx1_blknum == tx2_blknum and tx1_index < tx2_index)
end
