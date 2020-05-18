defmodule OMG.WatcherInfo.DB.Repo.Migrations.FetchEthHeightsForEthEvents do
  use Ecto.Migration
  alias OMG.Eth.Encoding
  alias OMG.WatcherInfo.DB

  import Ecto.Query, only: [from: 2]

  def up() do
    request_block_numbers()
    |> format_responses()
    |> Stream.each(&update_record/1)
  end

  defp request_block_numbers() do
    {:ok, batched_responses} =
      from(e in DB.EthEvent,
        where: is_nil(e.eth_height),
        select: e.root_chain_txhash
      )
      |> DB.Repo.all()
      |> Enum.map(&create_request/1)
      |> make_batched_request()

    batched_responses
  end

  defp create_request(root_chain_txhash) do
    {:eth_get_transaction_by_hash, [Encoding.to_hex(root_chain_txhash)]}
  end

  defp make_batched_request(requests) do
    case requests do
      [] ->
        {:ok, []}

      _ ->
        Ethereumex.HttpClient.batch_request(requests)
    end
  end

  defp format_responses(res) do
    Stream.map(res, fn event ->
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
    end)
  end

  def normalize_hash("0x" <> hex = hash) do
    case hex |> String.length() |> rem(2) do
      0 ->
        hash

      _ ->
        "0x0" <> hex
    end
  end

  defp update_record(%{root_chain_txhash: root_chain_txhash, eth_height: eth_height} = _response) do
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
