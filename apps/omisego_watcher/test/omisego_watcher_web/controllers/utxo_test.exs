defmodule OmiseGOWatcherWeb.Controller.UtxoTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures

  alias OmiseGO.API
  alias OmiseGO.API.Block
  alias OmiseGO.API.Crypto
  alias OmiseGO.API.TestHelper
  alias OmiseGO.API.Utxo
  require Utxo
  alias OmiseGOWatcher.TestHelper
  alias OmiseGOWatcher.TransactionDB
  alias OmiseGOWatcher.UtxoDB

  @eth Crypto.zero_address()
  @eth_hex String.duplicate("00", 20)

  describe "UTXO database." do
    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "No utxo are returned for non-existing addresses.", %{alice: alice} do
      {:ok, alice_address_encode} = Crypto.encode_address(alice.addr)
      assert get_utxo(alice.addr) == %{"utxos" => [], "address" => alice_address_encode}
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "Consumed block contents are available.", %{alice: alice} do
      UtxoDB.update_with(%Block{
        transactions: [
          API.TestHelper.create_recovered([], @eth, [{alice, 1947}]),
          API.TestHelper.create_recovered([], @eth, [{alice, 1952}])
        ],
        number: 2
      })

      %{"utxos" => [%{"amount" => amount1, "currency" => @eth_hex}, %{"amount" => amount2}]} = get_utxo(alice.addr)

      assert Enum.sort([amount1, amount2]) == [1947, 1952]
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob, :carol]
    test "Spent utxos are moved to new owner.", %{alice: alice, bob: bob, carol: carol} do
      UtxoDB.update_with(%Block{
        transactions: [
          API.TestHelper.create_recovered([], @eth, [{alice, 1843}]),
          API.TestHelper.create_recovered([], @eth, [{bob, 1871}])
        ],
        number: 1
      })

      %{"utxos" => [%{"amount" => 1871}]} = get_utxo(bob.addr)

      UtxoDB.update_with(%Block{
        transactions: [API.TestHelper.create_recovered([{1, 1, 0, bob}], @eth, [{carol, 1000}])],
        number: 2
      })

      %{"utxos" => [%{"amount" => 1000}]} = get_utxo(carol.addr)
      %{"utxos" => []} = get_utxo(bob.addr)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice]
    test "Deposits are a part of utxo set.", %{alice: alice} do
      assert %{"utxos" => []} = get_utxo(alice.addr)
      UtxoDB.insert_deposits([%{owner: alice.addr, currency: @eth, amount: 1, block_height: 1}])
      assert %{"utxos" => [%{"amount" => 1, "currency" => @eth_hex}]} = get_utxo(alice.addr)
    end

    @tag fixtures: [:phoenix_ecto_sandbox, :alice, :bob]
    test "Deposit utxo are moved to new owner if spent ", %{alice: alice, bob: bob} do
      assert %{"utxos" => []} = get_utxo(alice.addr)
      assert %{"utxos" => []} = get_utxo(bob.addr)
      UtxoDB.insert_deposits([%{owner: alice.addr, currency: @eth, amount: 1, block_height: 1}])
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo(alice.addr)

      UtxoDB.update_with(%Block{
        transactions: [API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, [{bob, 1}])],
        number: 2
      })

      assert %{"utxos" => []} = get_utxo(alice.addr)
      assert %{"utxos" => [%{"amount" => 1}]} = get_utxo(bob.addr)
    end
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "compose_utxo_exit should return proper proof format", %{alice: alice} do
    TransactionDB.update_with(%{
      transactions: [
        API.TestHelper.create_recovered([{1, 1, 0, alice}], @eth, [{alice, 120}]),
        API.TestHelper.create_recovered([{1, 1, 0, alice}], @eth, [{alice, 110}]),
        API.TestHelper.create_recovered([{2, 0, 0, alice}], @eth, [])
      ],
      number: 1
    })

    {:ok,
     %{
       utxo_pos: _utxo_pos,
       txbytes: _tx_bytes,
       proof: proof,
       sigs: _sigs
     }} = UtxoDB.compose_utxo_exit(Utxo.position(1, 1, 0))

    assert <<_proof::bytes-size(512)>> = proof
  end

  @tag fixtures: [:phoenix_ecto_sandbox]
  test "compose_utxo_exit should return error when there is no txs in specfic block" do
    {:error, :no_tx_for_given_blknum} = UtxoDB.compose_utxo_exit(Utxo.position(1, 1, 0))
  end

  @tag fixtures: [:phoenix_ecto_sandbox, :alice]
  test "compose_utxo_exit should return error when there is no tx in specfic block", %{alice: alice} do
    TransactionDB.update_with(%{
      transactions: [
        API.TestHelper.create_recovered([{1, 0, 0, alice}], @eth, []),
        API.TestHelper.create_recovered([{1, 1, 0, alice}], @eth, []),
        API.TestHelper.create_recovered([], @eth, [])
      ],
      number: 1
    })

    {:error, :no_tx_for_given_blknum} = UtxoDB.compose_utxo_exit(Utxo.position(1, 4, 0))
  end

  defp get_utxo(address) do
    {:ok, address_encode} = Crypto.encode_address(address)
    TestHelper.rest_call(:get, "account/utxo?address=#{address_encode}")
  end
end
