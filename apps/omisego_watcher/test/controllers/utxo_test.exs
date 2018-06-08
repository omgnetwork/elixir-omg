defmodule OmiseGOWatcherWeb.Controller.UtxoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGOWatcher.UtxoDB
  alias OmiseGO.API.{Block}
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}
  alias OmiseGOWatcher.TransactionDB
  alias OmiseGOWatcherWeb.Controller.Utxo

  @moduletag :watcher_tests

  @empty %Transaction{
    blknum1: 0,
    txindex1: 0,
    oindex1: 0,
    blknum2: 0,
    txindex2: 0,
    oindex2: 0,
    newowner1: "",
    amount1: 0,
    newowner2: "",
    amount2: 0,
    fee: 0
  }

  @signed_tx %Signed{
    raw_tx: @empty,
    sig1: <<>>,
    sig2: <<>>
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmiseGOWatcher.Repo)
  end

  describe "UTXO database." do
    test "No utxo are returned for non-existing addresses." do
      assert get_utxo("cthulhu") == %{"utxos" => [], "address" => "cthulhu"}
    end

    test "Consumed block contents are available." do
      UtxoDB.consume_block(
        %Block{
          transactions: [
            @empty |> Map.merge(%{newowner1: "McDuck", amount1: 1947}) |> signed,
            @empty |> Map.merge(%{newowner1: "McDuck", amount1: 1952}) |> signed
          ]
        },
        2
      )

      %{"address" => "McDuck", "utxos" => [%{"amount" => amount1}, %{"amount" => amount2}]} =
        get_utxo("McDuck")

      assert Enum.sort([amount1, amount2]) == [1947, 1952]
    end

    test "Spent utxos are moved to new owner." do
      UtxoDB.consume_block(
        %Block{
          transactions: [
            @empty |> Map.merge(%{newowner1: "Ebenezer", amount1: 1843}) |> signed,
            @empty |> Map.merge(%{newowner1: "Matilda", amount1: 1871}) |> signed
          ]
        },
        1
      )

      %{"utxos" => [%{"amount" => 1871}]} = get_utxo("Matilda")

      UtxoDB.consume_block(
        %Block{
          transactions: [
            @empty
            |> Map.merge(%{
              newowner1: "McDuck",
              amount1: 1000,
              blknum1: 1,
              txindex1: 1,
              oindex1: 0
            })
            |> signed
          ]
        },
        2
      )

      %{"utxos" => [%{"amount" => 1000}]} = get_utxo("McDuck")
      %{"utxos" => []} = get_utxo("Matilda")
    end

    test "Deposits are a part of utxo set." do
      assert %{"utxos" => []} = get_utxo("Leon")
      UtxoDB.record_deposits([%{owner: "Leon", amount: 1, block_height: 1}])
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo("Leon")
    end

    test "Deposit utxo are moved to new owner if spent " do
      assert %{"utxos" => []} = get_utxo("Leon")
      assert %{"utxos" => []} = get_utxo("Matilda")
      UtxoDB.record_deposits([%{owner: "Leon", amount: 1, block_height: 1}])
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo("Leon")

      spent = %{
        newowner1: "Matilda",
        amount1: 1,
        blknum1: 1,
        txindex1: 0,
        oindex1: 0
      }

      UtxoDB.consume_block(
        %Block{
          transactions: [
            @empty
            |> Map.merge(spent)
            |> signed
          ]
        },
        2
      )

      assert %{"utxos" => []} = get_utxo("Leon")
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo("Matilda")
    end
  end

# TODO Complete test
  test "compose proof from valid utxo" do
    TransactionDB.insert(<<1>>, @signed_tx, 1, 1)
    TransactionDB.insert(<<2>>, @signed_tx, 1, 2)
    TransactionDB.insert(<<3>>, @signed_tx, 1, 3)

    %{
      utxo_pos: 2,
      tx_bytes: <<202, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128>>,
      proof: <<242, 238, 21, 234, 99, 155, 115, 250, 61, 185, 179, 74, 36, 91, 223,
              160, 21, 194, 96, 197, 152, 178, 17, 191, 5, 161, 236, 196, 179, 227, 180,
    242, 1, 7, 151, 184, 46, 69, 228, 184, 78, 132, 19, 222, 72, 150, 170, 155,
    104, 186, 33, 157, 20, 65, 150, 250, 105, 127, 207, 120, 75, 27, 67, 230,
    180, 193, 25, 81, 149, 124, 111, 143, 100, 44, 74, 246, 28, 214, 178, 70,
    64, 254, 198, 220, 127, 198, 7, 238, 130, 6, 169, 158, 146, 65, 13, 48, 33,
    221, 185, 163, 86, 129, 92, 63, 172, 16, 38, 182, 222, 197, 223, 49, 36,
    175, 186, 219, 72, 92, 155, 165, 163, 227, 57, 138, 4, 183, 186, 133, 229,
    135, 105, 179, 42, 27, 234, 241, 234, 39, 55, 90, 68, 9, 90, 13, 31, 182,
    100, 206, 45, 211, 88, 231, 252, 191, 183, 140, 38, 161, 147, 68, 14, 176,
    30, 191, 201, 237, 39, 80, 12, 212, 223, 201, 121, 39, 45, 31, 9, 19, 204,
    159, 102, 84, 13, 126, 128, 5, 129, 17, 9, 225, 207, 45, 136, 124, 34, 189,
    135, 80, 211, 64, 22, 172, 60, 102, 181, 255, 16, 45, 172, 221, 115, 246,
    176, 20, 231, 16, 181, 30, 128, 34, 175, 154, 25, 104, 255, 215, 1, 87, 228,
    128, 99, 252, 51, 201, 122, 5, 15, 127, 100, 2, 51, 191, 100, 108, 201, 141,
    149, 36, 198, 185, 43, 207, 58, 181, 111, 131, 152, 103, 204, 95, 127, 25,
    107, 147, 186, 225, 226, 126, 99, 32, 116, 36, 69, 210, 144, 242, 38, 56,
    39, 73, 139, 84, 254, 197, 57, 247, 86, 175, 206, 250, 212, 229, 8, 192,
    152, 185, 167, 225, 216, 254, 177, 153, 85, 251, 2, 186, 150, 117, 88, 80,
    120, 113, 9, 105, 211, 68, 15, 80, 84, 224, 249, 220, 62, 127, 224, 22, 224,
    80, 239, 242, 96, 51, 79, 24, 165, 212, 254, 57, 29, 130, 9, 35, 25, 245,
    150, 79, 46, 46, 183, 193, 195, 165, 248, 177, 58, 73, 226, 130, 246, 9,
    195, 23, 168, 51, 251, 141, 151, 109, 17, 81, 124, 87, 29, 18, 33, 162, 101,
    210, 90, 247, 120, 236, 248, 146, 52, 144, 198, 206, 235, 69, 10, 236, 220,
    130, 226, 130, 147, 3, 29, 16, 199, 215, 59, 248, 94, 87, 191, 4, 26, 151,
    54, 10, 162, 197, 217, 156, 193, 223, 130, 217, 196, 184, 116, 19, 234, 226,
    239, 4, 143, 148, 180, 211, 85, 76, 234, 115, 217, 43, 15, 122, 249, 110, 2,
    113, 198, 145, 226, 187, 92, 103, 173, 215, 198, 202, 243, 2, 37, 106, 222,
    223, 122, 177, 20, 218, 10, 207, 232, 112, 212, 73, 163, 164, 137, 247, 129,
    214, 89, 232, 190, 204, 218, 123, 206, 159, 78, 134, 24, 182, 189, 47, 65,
    50, 206, 121, 140, 220, 122, 96, 231, 225, 70, 10, 114, 153, 227, 198, 52,
    42, 87, 150, 38, 210>>,
      sigs: <<>>
    } =UtxoDB.compose_utxo_exit(1, 1, 0)
  end

  defp compose_utxo_exit(block_height, txindex, oindex) do
    conn(:get, "account/utxo/compose_exit?block_height=#{block_height}&txindex=#{txindex}&oindex=#{oindex}")
      |> check_request
  end

  defp get_utxo(address) do
    conn(:get, "account/utxo?address=#{address}")
      |> check_request
  end

  defp get_utxo(address) do
    conn(:get, "account/utxo?address=#{address}")
      |> check_request
  end

  defp check_request(request) do
    response = request |> send_request
    assert response.status == 200
    Poison.decode!(response.resp_body)
  end

  defp signed(transaction) do
    %Signed{raw_tx: transaction}
  end

  defp send_request(conn) do
    conn
    |> put_private(:plug_skip_csrf_protection, true)
    |> OmiseGOWatcherWeb.Endpoint.call([])
  end
end
