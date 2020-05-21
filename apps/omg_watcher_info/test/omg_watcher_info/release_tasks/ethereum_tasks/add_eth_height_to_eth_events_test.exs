defmodule OMG.WatcherInfo.ReleaseTasks.AddEthHeightToEthEventsTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  use OMG.WatcherInfo.Fixtures

  alias OMG.Eth.Encoding
  alias OMG.WatcherInfo.DB

  import Ecto.Query, only: [from: 2]

  import OMG.WatcherInfo.Factory
  import OMG.WatcherInfo.ReleaseTasks.EthereumTasks.AddEthereumHeightToEthEvents

  describe "stream_events_from_db" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "only returns a `root_chain_txhash` for `eth_events` with a `nil` `eth_height`" do
      event_with_eth_height = insert(:ethevent, %{eth_height: 1})
      _event_nil_eth_height_1 = insert(:ethevent, %{eth_height: nil})
      _event_nil_eth_height_2 = insert(:ethevent, %{eth_height: nil})

      {:ok, result} =
        DB.Repo.transaction(fn ->
          stream_events_from_db()
          |> Enum.to_list()
        end)

      assert length(result) == 2

      Enum.each(result, fn hash ->
        assert hash !== event_with_eth_height.root_chain_txhash
      end)
    end
  end

  describe "make_batched_requests/1" do
    test "returns an empty list if given an empty list" do
      assert [] == make_batched_request([])
    end
  end

  describe "format_response/1" do
    test "executes formating as per specification" do
      event_1 = %{
        "blockNumber" => "0x0eb0",
        "hash" => "0xd62645c98e3056ba053fc8a1eb6e4f4acbca2a92649c6c849ce70ef43daaee55"
      }

      # Same event - but with an odd-length hexadecimal string.
      event_2 = %{
        "blockNumber" => "0xeb0",
        "hash" => "0xd62645c98e3056ba053fc8a1eb6e4f4acbca2a92649c6c849ce70ef43daaee55"
      }

      expected_result = %{
        eth_height: event_1 |> Map.get("blockNumber") |> Encoding.from_hex() |> :binary.decode_unsigned(),
        root_chain_txhash: event_1 |> Map.get("hash") |> Encoding.from_hex()
      }

      # Result should be the same for both.
      assert format_response(event_1) == expected_result
      assert format_response(event_2) == expected_result
    end
  end

  describe "update_record/1" do
    @tag fixtures: [:phoenix_ecto_sandbox]
    test "updates an event with given `root_chain_txhash` with given `eth_height`" do
      %{root_chain_txhash: root_chain_txhash} = insert(:ethevent, %{eth_height: nil})
      assert :ok = update_record(%{root_chain_txhash: root_chain_txhash, eth_height: 123})

      %{eth_height: eth_height} =
        from(e in DB.EthEvent,
          where: e.root_chain_txhash == ^root_chain_txhash,
          select: e
        )
        |> DB.Repo.all()
        |> Enum.at(0)

      assert eth_height == 123
    end
  end
end
