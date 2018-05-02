defmodule OmiseGOWatcherWeb.Controller.TransactionTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false

  use Plug.Test

  alias OmiseGOWatcher.TransactionDB
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}
  alias OmiseGO.API.{Block}

  @moduletag :watcher_tests

  @signed_tx %Signed{
    raw_tx: %Transaction{
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
    },
    sig1: <<>>,
    sig2: <<>>
  }

  deffixture db_path_config() do
    dir = Temp.mkdir!()

    Application.put_env(:omisego_db, :leveldb_path, dir, persistent: true)
    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    on_exit fn ->
      Application.put_env(:omisego_db, :leveldb_path, nil)
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  # FIXME: copied from eth/fixtures - DRY
  deffixture geth do
    {:ok, exit_fn} = OmiseGO.Eth.dev_geth()
    on_exit(exit_fn)
    :ok
  end

  # FIXME: copied from eth/fixtures - DRY
  deffixture contract(geth) do
    _ = geth
    _ = Application.ensure_all_started(:ethereumex)
    {:ok, contract_address, txhash, authority} = OmiseGO.Eth.DevHelpers.prepare_env("../../")

    %{
      address: contract_address,
      from: authority,
      txhash: txhash
    }
  end

  deffixture root_chain_contract_config(geth, contract) do
    # prevent warnings
    :ok = geth

    Application.put_env(:omisego_eth, :contract, contract.address, persistent: true)
    Application.put_env(:omisego_eth, :authority_addr, contract.from, persistent: true)
    Application.put_env(:omisego_eth, :txhash_contract, contract.txhash, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_eth)

    on_exit fn ->
      Application.put_env(:omisego_eth, :contract, "0x0")
      Application.put_env(:omisego_eth, :authority_addr, "0x0")
      Application.put_env(:omisego_eth, :txhash_contract, "0x0")
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  deffixture db_initialized(db_path_config) do
    :ok = db_path_config
    :ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])
    # FIXME the latter doesn't work yet
    # OmiseGO.DB.multi_update([{:put, :child_top_block_number, 0}])
    :ok
  end

  deffixture omisego(root_chain_contract_config, db_initialized) do
    :ok = root_chain_contract_config
    :ok = db_initialized
    {:ok, started_apps} = Application.ensure_all_started(:omisego_watcher)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(OmiseGOWatcher.Repo)

    on_exit fn ->
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  @tag fixtures: [:omisego]
  test "insert and retrieve transaction" do
    txblknum = 0
    txindex = 0
    id = Signed.signed_hash(@signed_tx)

    {:ok, %TransactionDB{txid: id}} = TransactionDB.insert(id, @signed_tx, txblknum, txindex)

    expected_transaction = create_expected_transaction(id, @signed_tx, txblknum, txindex)

    assert expected_transaction == delete_meta(TransactionDB.get(id))
  end

  @tag fixtures: [:omisego]
  test "insert and retrieve block of transactions" do
    txblknum = 0

    signed_tx_1 = @signed_tx
    signed_tx_2 = put_in(@signed_tx.raw_tx.blknum1, 1)

    [{:ok, %TransactionDB{txid: txid_1}}, {:ok, %TransactionDB{txid: txid_2}}] =
      TransactionDB.insert(
        %Block{
          transactions: [
            signed_tx_1,
            signed_tx_2
          ]
        },
        txblknum
      )

    expected_transaction_1 = create_expected_transaction(txid_1, signed_tx_1, txblknum, 0)
    expected_transaction_2 = create_expected_transaction(txid_2, signed_tx_2, txblknum, 1)

    assert expected_transaction_1 == delete_meta(TransactionDB.get(txid_1))
    assert expected_transaction_2 == delete_meta(TransactionDB.get(txid_2))
  end

  describe "get transaction spending utxo" do

    @tag fixtures: [:omisego]
    test "returns transaction that spends utxo" do
      id = Signed.signed_hash(@signed_tx)
      {:ok, %TransactionDB{txid: ^id}} = TransactionDB.insert(id, @signed_tx, 1, 1)

      utxo = %{blknum: @signed_tx.blknum1, txindex: @signed_tx.txindex1, oindex: @signed_tx.oindex1}
      {:ok, %TransactionDB{txid: ^id}} = TransactionDB.get_transaction_spending_utxo(utxo)
    end

    @tag fixtures: [:omisego]
    test "signals when spending transaction does not exist" do
    end

  end

  defp create_expected_transaction(txid, signed_tx, txblknum, txindex) do
    %TransactionDB{
      txblknum: txblknum,
      txindex: txindex,
      txid: txid
    }
    |> Map.merge(Map.from_struct(signed_tx.raw_tx))
    |> delete_meta
  end

  defp delete_meta(%TransactionDB{} = transaction) do
    Map.delete(transaction, :__meta__)
  end
end
