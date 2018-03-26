defmodule OmisegoWalletWeb.Controller.UtxoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmisegoWalletWeb.Controller.Utxo
  alias OmiseGO.API.{Block}
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}

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

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmisegoWallet.Repo)
  end

  test "check not existing addres" do
    assert get_utxo("cthulhu") == %{"utxos" => [], "addres" => "cthulhu"}
  end

  test "deposit new utxo amount" do
    Utxo.consume_block(
      %Block{
        transactions: [
          @empty |> Map.merge(%{newowner1: "McDuck", amount1: 1947}) |> signed,
          @empty |> Map.merge(%{newowner1: "McDuck", amount1: 1952}) |> signed
        ]
      },
      2
    )

    %{"addres" => "McDuck", "utxos" => [%{"amount" => amount1}, %{"amount" => amount2}]} =
      get_utxo("McDuck")

    assert Enum.sort([amount1, amount2]) == [1947, 1952]
  end

  test "spend utxo/update utxos" do
    Utxo.consume_block(
      %Block{
        transactions: [
          @empty |> Map.merge(%{newowner1: "Ebenezer", amount1: 1843}) |> signed,
          @empty |> Map.merge(%{newowner1: "Matilda", amount1: 1871}) |> signed
        ]
      },
      1
    )
    %{"utxos" => [%{"amount" => 1871}]} = get_utxo("Matilda")
    Utxo.consume_block(
      %Block{
        transactions: [
          @empty
          |> Map.merge(%{newowner1: "McDuck", amount1: 1000, blknum1: 1, txindex1: 1, oindex1: 0})
          |> signed
        ]
      },
      2
    )

    %{"utxos" => [%{"amount" => 1000}]} = get_utxo("McDuck")
    %{"utxos" => []} = get_utxo("Matilda")
  end

  defp get_utxo(addres) do
    request = conn(:get, "account/utxo?addres=#{addres}")
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
    |> OmisegoWalletWeb.Endpoint.call([])
  end
end
