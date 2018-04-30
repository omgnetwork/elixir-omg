defmodule OmiseGO.API.State.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API.State.{Transaction, Transaction.Recovered, Core}
  alias OmiseGO.API.TestHelper

  @signature <<1>> |> List.duplicate(65) |> :binary.list_to_bin()

  deffixture transaction do
    %Transaction{
      blknum1: 1,
      txindex1: 1,
      oindex1: 0,
      blknum2: 1,
      txindex2: 2,
      oindex2: 1,
      newowner1: "alicealicealicealice",
      amount1: 1,
      newowner2: "carolcarolcarolcarol",
      amount2: 2,
      fee: 0
    }
  end

  deffixture utxos do
    %{
      address: "McDuck",
      utxos: [
        %{
          amount: 100,
          blknum: 20,
          oindex: 1,
          txbytes: "not important",
          txindex: 42
        },
        %{
          amount: 43,
          blknum: 2,
          oindex: 0,
          txbytes: "ble ble bla",
          txindex: 21
        }
      ]
    }
  end

  @tag fixtures: [:transaction]
  test "transaction hash is correct", %{transaction: transaction} do
    assert Transaction.hash(transaction) ==
             <<206, 180, 169, 245, 52, 190, 189, 248, 33, 15, 103, 145, 4, 195, 170, 59, 137, 102,
               245, 238, 22, 172, 18, 240, 21, 132, 30, 1, 197, 112, 101, 192>>
  end

  @tag fixtures: [:transaction]
  test "signed transaction hash is correct", %{transaction: transaction} do
    signed = %Transaction.Signed{raw_tx: transaction, sig1: @signature, sig2: @signature}

    expected =
      <<206, 180, 169, 245, 52, 190, 189, 248, 33, 15, 103, 145, 4, 195, 170, 59, 137, 102, 245,
        238, 22, 172, 18, 240, 21, 132, 30, 1, 197, 112, 101, 192>> <> signed.sig1 <> signed.sig2

    actual = Transaction.Signed.signed_hash(signed)
    assert actual == expected
  end

  @tag fixtures: [:utxos]
  test "crete transaction", %{utxos: utxos} do
    {:ok, transaction} =
      Transaction.create_from_utxos(utxos, %{address: "Joe Black", amount: 53}, 50)

    assert transaction == %Transaction{
             blknum1: 20,
             txindex1: 42,
             oindex1: 1,
             blknum2: 2,
             txindex2: 21,
             oindex2: 0,
             newowner1: "Joe Black",
             amount1: 53,
             newowner2: "McDuck",
             amount2: 40,
             fee: 50
           }
  end

  @tag fixtures: [:utxos]
  test "checking error messages", %{utxos: utxos} do
    assert {:error, :amount_negative_value} ==
             Transaction.create_from_utxos(utxos, %{address: "Joe", amount: -4}, 2)

    assert {:error, :amount_negative_value} ==
             Transaction.create_from_utxos(utxos, %{address: "Joe", amount: 30_000}, 0)

    assert {:error, :fee_negative_value} ==
             Transaction.create_from_utxos(utxos, %{address: "Joe", amount: 30}, -2)

    assert {:error, :too_many_utxo} ==
             Transaction.create_from_utxos(
               %{utxos | utxos: utxos.utxos ++ utxos.utxos},
               %{address: "Joe", amount: 3},
               0
             )
  end

  @tag fixtures: [:alice, :state_empty, :bob]
  test "using created transaction in Core.exec", %{alice: alice, bob: bob, state_empty: state} do
    state =
      state |> TestHelper.do_deposit(alice, %{amount: 100, blknum: 1})
      |> TestHelper.do_deposit(alice, %{amount: 10, blknum: 2})

    utxos_json = """
    {
      "address": "#{Base.encode16(alice.addr)}",
      "utxos": [
        { "amount": 100, "blknum": 1, "oindex": 0, "txindex": 0 },
        { "amount": 10, "blknum": 2, "oindex": 0, "txindex": 0 }
      ]
    }
    """

    utxos = Poison.Parser.parse!(utxos_json, keys: :atoms!)
    {:ok, decode_address} = Base.decode16(utxos.address)
    utxos = %{utxos | address: decode_address}

    {:ok, transaction} =
      Transaction.create_from_utxos(utxos, %{address: bob.addr, amount: 42}, 10)

    assert {{:ok, _, _, _}, _state} =
             transaction
             |> Transaction.sign(alice.priv, alice.priv)
             |> Recovered.recover_from()
             |> Core.exec(state)
  end
end
