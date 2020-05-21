defmodule OMG.WatcherInfo.ReleaseTasks.EthereumTasks.AddEthereumHeightToEthEvents do
  @moduledoc """
  Running in May 2020.
  `eth_height` is currently not persisted in the Watcher Info DB for `eth_events`
  This module will add `eth_height` to all persisted `eth_events` where this value is non-existent.
  """
  use Ecto.Migration
  alias OMG.Eth.Encoding
  alias OMG.WatcherInfo.DB

  import Ecto.Query, only: [from: 2]

  @max_db_rows 100
  @max_eth_requests 25

  def run() do
    DB.Repo.transaction(fn ->
      stream_events_from_db()
      |> stream_create_requests()
      |> stream_batch_requests()
      |> stream_make_requests()
      |> stream_concatenate_responses()
      |> stream_format_responses()
      |> Enum.map(&update_record/1)
    end)
  end

  def stream_events_from_db() do
    query =
      from(e in DB.EthEvent,
        where: is_nil(e.eth_height),
        select: e.root_chain_txhash
      )

    DB.Repo.stream(query, max_rows: @max_db_rows)
  end

  def stream_create_requests(events_stream) do
    Stream.map(events_stream, fn root_chain_txhash ->
      {:eth_get_transaction_by_hash, [Encoding.to_hex(root_chain_txhash)]}
    end)
  end

  def stream_batch_requests(request_stream) do
    Stream.chunk_every(request_stream, @max_eth_requests)
  end

  def stream_make_requests(batched_request_stream) do
    Stream.map(batched_request_stream, &make_batched_request/1)
  end

  def make_batched_request(eth_requests) do
    case eth_requests do
      [] ->
        []

      _ ->
        {:ok, batched_responses} = Ethereumex.HttpClient.batch_request(eth_requests)
        batched_responses
    end
  end

  def stream_concatenate_responses(batched_response_stream) do
    Stream.concat(batched_response_stream)
  end

  defp stream_format_responses(response_stream) do
    Stream.map(response_stream, &format_response/1)
  end

  def format_response(event) do
    eth_height =
      event
      |> Map.get("blockNumber")
      |> normalize_hash()
      |> Encoding.from_hex()
      |> :binary.decode_unsigned()

    root_chain_txhash =
      event
      |> Map.get("hash")
      |> Encoding.from_hex()

    %{root_chain_txhash: root_chain_txhash, eth_height: eth_height}
  end

  def normalize_hash("0x" <> hex = hash) do
    case hex |> String.length() |> rem(2) do
      0 ->
        hash

      _ ->
        "0x0" <> hex
    end
  end

  def update_record(%{root_chain_txhash: root_chain_txhash, eth_height: eth_height} = _response) do
    from(e in DB.EthEvent,
      where: e.root_chain_txhash == ^root_chain_txhash,
      select: e
    )
    |> DB.Repo.all()
    |> Enum.each(fn event ->
      event
      |> Ecto.Changeset.change(%{eth_height: eth_height})
      |> DB.Repo.update()
    end)
  end
end
