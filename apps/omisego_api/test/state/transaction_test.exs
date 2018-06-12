defmodule OmiseGO.API.State.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias OmiseGO.API
  alias OmiseGO.API.State.{Core, Transaction}
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
             <<204, 238, 74, 144, 230, 127, 34, 158, 0, 227, 29, 20, 146, 214,
              197, 5, 221, 167, 231, 108, 84, 86, 189, 191, 156, 180, 26, 37,
              93, 4, 75, 249>>
  end

  @tag fixtures: [:transaction]
  test "signed transaction hash is correct", %{transaction: transaction} do
    signed = %Transaction.Signed{raw_tx: transaction, sig1: @signature, sig2: @signature}

    expected =
      <<204, 238, 74, 144, 230, 127, 34, 158, 0, 227, 29, 20, 146, 214,
        197, 5, 221, 167, 231, 108, 84, 86, 189, 191, 156, 180, 26, 37,
        93, 4, 75, 249>> <> signed.sig1 <> signed.sig2

    actual = Transaction.Signed.signed_hash(signed)
    assert actual == expected
  end

  @tag fixtures: [:utxos]
  test "crete transaction", %{utxos: utxos} do
    {:ok, transaction} = Transaction.create_from_utxos(utxos, %{address: "Joe Black", amount: 53}, 50)

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
    assert {:error, :amount_negative_value} == Transaction.create_from_utxos(utxos, %{address: "Joe", amount: -4}, 2)

    assert {:error, :amount_negative_value} ==
             Transaction.create_from_utxos(utxos, %{address: "Joe", amount: 30_000}, 0)

    assert {:error, :fee_negative_value} == Transaction.create_from_utxos(utxos, %{address: "Joe", amount: 30}, -2)

    assert {:error, :too_many_utxo} ==
             Transaction.create_from_utxos(
               %{utxos | utxos: utxos.utxos ++ utxos.utxos},
               %{address: "Joe", amount: 3},
               0
             )
  end

  @tag fixtures: [:alice, :state_empty, :bob]
  test "using created transaction in child chain", %{alice: alice, bob: bob, state_empty: state} do
    state =
      state
      |> TestHelper.do_deposit(alice, %{amount: 100, blknum: 1})
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

    {:ok, raw_transaction} = Transaction.create_from_utxos(utxos, %{address: bob.addr, amount: 42}, 10)

    {:ok, transaction} =
      raw_transaction
      |> Transaction.sign(alice.priv, alice.priv)
      |> Transaction.Signed.encode()
      |> API.Core.recover_tx()

    assert {{:ok, _, _, _}, _state} =
             transaction
             |> Core.exec(state)
  end
end
