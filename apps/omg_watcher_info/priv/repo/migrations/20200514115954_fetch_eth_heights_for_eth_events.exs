defmodule OMG.WatcherInfo.DB.Repo.Migrations.FetchEthHeightsForEthEvents do
  use Ecto.Migration

  alias OMG.Eth.Encoding
  alias OMG.WatcherInfo.DB

  def change do
  end

  defp request_block_numbers do
    {:ok, batched_responses} =
      from(event in DB.EthEvent, select: event)
      |> DB.Repo.all()
      |> Enum.map(&create_request_from_event/1)
      |> Ethereumex.HttpClient.batch_request()

    batched_responses
  end

  defp create_request_from_event(event) do
    hex_hash =
      event
      |> Map.get(:root_chain_txhash)
      |> Encoding.to_hex()

    {:eth_get_transaction_by_hash, [hex_hash]}
  end

  defp format_responses(res) do
    Enum.map(res, fn event ->
      eth_height =
        event
        |> Map.get("blockNumber")
        |> Encoding.from_hex()
        |> :binary.decode_unsigned()

      %{root_chain_txhash: event["hash"], eth_height: eth_height}
    end)
  end
end
