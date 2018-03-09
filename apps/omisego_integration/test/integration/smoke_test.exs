defmodule HonteD.Integration.SmokeTest do
  @moduledoc """
  Smoke tests the integration of abci/ws/jsonrpc/elixir_api/eventer applications in the wild

  FIXME: Main test is just one blob off tests taken from demos - consider engineering here
  FIXME: In case API unit test come to existence, consider removing some of these tests here and becoming more targetted
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias HonteD.{Crypto, API, Integration, Eth, Transaction}

  @supply 5
  @tm_pubkey "FEFB8740A301134C7762E38241B59FC8181D982A1DE629F7168622A863E9BCAA"

  @moduletag :integration

  defmodule TestWebsocket do
    @moduledoc """
    A Websocket client used to test the honted_ws server
    """
    def connect!() do
      ws_port = Application.get_env(:honted_ws, :honted_api_ws_port)
      Socket.Web.connect!("localhost", ws_port)
    end

    def send!(websocket, method, params) when is_atom(method) and is_map(params) do
      encoded_message = Poison.encode!(%{wsrpc: "1.0", type: :rq, method: method, params: params})
      websocket
      |> Socket.Web.send!({
        :text,
        encoded_message
      })
    end

    def recv!(websocket) do
      {:text, response} = Socket.Web.recv!(websocket)
      case Poison.decode!(response) do
        %{"result" => decoded_result, "type" => "rs", "wsrpc" => "1.0"} -> {:ok, decoded_result}
        %{"source" => source} = event when is_binary(source) -> event
        %{"error" => decoded_error, "type" => "rs", "wsrpc" => "1.0"} -> {:error, decoded_error}
      end
    end

    @doc """
    Merges both above functions to send query and immediately fetch the response that comes in in next
    """
    def sendrecv!(websocket, method, params) when is_atom(method) and is_map(params) do
      :ok = TestWebsocket.send!(websocket, method, params)
      TestWebsocket.recv!(websocket)
    end

    @doc """
    Trick play to coerce the results to form as given by external apis (e.g. strings instead of atoms for keys)
    """
    def codec(term) do
      term
      |> Poison.encode!
      |> Poison.decode!
    end
  end

  deffixture websocket(honted) do
    :ok = honted
    TestWebsocket.connect!()
  end

  deffixture jsonrpc do
    jsonrpc_port = Application.get_env(:honted_jsonrpc, :honted_api_rpc_port)
    fn (method, params) ->
      "http://localhost:#{jsonrpc_port}"
      |> JSONRPC2.Clients.HTTP.call(to_string(method), params)
      |> case do
        # JSONRPC Client returns the result in a specific format. We need to bring to common format with WS client
        {:error, {code, message, data}} -> {:error, %{"code" => code, "message" => message, "data" => data}}
        other_result -> other_result
      end
    end
  end

  deffixture apis_caller(websocket, jsonrpc) do
    # convenience function to check if calls to both apis are at least the same
    fn (method, params) ->
      resp1 = TestWebsocket.sendrecv!(websocket, method, params)
      resp2 = jsonrpc.(method, params)
      assert resp1 == resp2
      resp1
    end
  end

  ###
  ### apis/honted/tendermint integration
  ###

  @tag fixtures: [:tendermint, :websocket, :apis_caller]
  test "demo smoke test", %{websocket: websocket, apis_caller: apis_caller} do
    {:ok, issuer_priv} = Crypto.generate_private_key()
    {:ok, issuer_pub} = Crypto.generate_public_key(issuer_priv)
    {:ok, issuer} = Crypto.generate_address(issuer_pub)

    {:ok, alice_priv} = Crypto.generate_private_key()
    {:ok, alice_pub} = Crypto.generate_public_key(alice_priv)
    {:ok, alice} = Crypto.generate_address(alice_pub)

    {:ok, bob_priv} = Crypto.generate_private_key()
    {:ok, bob_pub} = Crypto.generate_public_key(bob_priv)
    {:ok, bob} = Crypto.generate_address(bob_pub)

    # BROADCAST_TX_* SEMANTICS CHECKS

    # submit_commit should do CheckTx and fail
    {:ok, raw_tx} = API.create_create_token_transaction(bob)
    no_signature_tx = raw_tx
    assert {:error, %{reason: :check_tx_failed}} = API.submit_commit(no_signature_tx)

    # submit_sync should do CheckTx and fail
    assert {:error, %{reason: :submit_failed}} = API.submit_sync(no_signature_tx)

    # submit_async does no checks, should return tx id and indicate success
    assert {:ok, %{tx_hash: hash}} = API.submit_async(no_signature_tx)
    assert {:error, _} = API.tx(hash)

    token_creation = fn() ->
      {:ok, raw_tx} = API.create_create_token_transaction(bob)
      Transaction.sign(raw_tx, bob_priv)
    end

    # submit_commit succeeds
    assert {:ok, %{tx_hash: hash}} = token_creation.() |> API.submit_commit()
    assert {:ok, _} = API.tx(hash)

    # submit_sync does checkTx and succeeds
    assert {:ok, %{tx_hash: _}} = token_creation.() |> API.submit_sync()

    Process.sleep(2000)
    # submit_async does not do full checkTx end, should return tx id
    assert {:ok, %{tx_hash: hash}} = token_creation.() |> API.submit_async()
    # tx should be mined after some time
    Process.sleep(2000)
    assert {:ok, _} = API.tx(hash)

    # CREATING TOKENS
    {:ok, raw_tx} = API.create_create_token_transaction(issuer)

    # check consistency of api exposers
    assert {:ok, raw_tx} == apis_caller.(:create_create_token_transaction, %{issuer: issuer})

    # TRANSACTION SUBMISSIONS
    full_transaction = Transaction.sign(raw_tx, issuer_priv)

    assert {:ok,
      %{
        committed_in: _,
        tx_hash: _some_hash
      }
    } = API.submit_commit(full_transaction)

    # duplicate
    assert {:error, %{raw_result: _}}
      = API.submit_commit(full_transaction)

    # sane invalid transaction response
    assert {:error,
      %{
        code: 1,
        data: "",
        log: "missing_signature",
        reason: :check_tx_failed,
        tx_hash: _
      }
    } = API.submit_commit(raw_tx)

    # LISTING TOKENS
    assert {:ok, [asset]} = API.tokens_issued_by(issuer)

    # check consistency of api exposers
    assert {:ok, [^asset]} =
      apis_caller.(:tokens_issued_by, %{issuer: issuer})

    # check consistency of api exposers
    assert {:ok, [asset]} == apis_caller.(:tokens_issued_by, %{issuer: issuer})

    # ISSUEING
    {:ok, raw_tx} = API.create_issue_transaction(asset, @supply, alice, issuer)

    # check consistency of api exposers
    assert {:ok, raw_tx} == apis_caller.(
      :create_issue_transaction,
      %{asset: asset, amount: @supply, to: alice, issuer: issuer}
    )

    # TODO: DRY refactor these into a separate function
    {:ok, _} =
      raw_tx
      |> Transaction.sign(issuer_priv)
      |> API.submit_commit()

    # QUERYING BALANCE
    assert {:ok, @supply} = API.query_balance(asset, alice)

    # check consistency of api exposers
    assert {:ok, @supply} == apis_caller.(:query_balance, %{token: asset, address: alice})

    # UNISSUING
    {:ok, raw_tx} = API.create_issue_transaction(asset, @supply, issuer, issuer)
    {:ok, _} =
      raw_tx
      |> Transaction.sign(issuer_priv)
      |> API.submit_commit()

    {:ok, raw_tx} = API.create_unissue_transaction(asset, @supply, issuer)

    # check consistency of api exposers
    assert {:ok, raw_tx} == apis_caller.(
      :create_unissue_transaction,
      %{asset: asset, amount: @supply, issuer: issuer}
    )

    {:ok, _} =
      raw_tx
      |> Transaction.sign(issuer_priv)
      |> API.submit_commit()

    # EVENTS & Send TRANSACTION
    # subscribe to filter
    assert {
      :ok,
      %{"new_filter" => filter_id, "start_height" => height}
    } = TestWebsocket.sendrecv!(websocket, :new_send_filter, %{watched: bob})

    assert height > 0 and is_integer(height) # smoke test this, no way to test this sensibly
    assert {:ok, [^bob]} = TestWebsocket.sendrecv!(websocket, :status_filter, %{filter_id: filter_id})

    {:ok, raw_tx} = API.create_send_transaction(asset, 5, alice, bob)

    # check consistency of api exposers
    assert {:ok, raw_tx} == apis_caller.(
      :create_send_transaction,
      %{asset: asset, amount: 5, from: alice, to: bob}
    )

    {:ok, %{tx_hash: tx_hash, committed_in: send_height}} =
      raw_tx
      |> Transaction.sign(alice_priv)
      |> API.submit_commit()

    # check event
    assert %{
      "transaction" => %{
        "tx" => %{
          "amount" => 5,
          "asset" => ^asset,
          "from" => ^alice,
          "nonce" => 0,
          "to" => ^bob
        },
        "hash" => ^tx_hash
      },
      "finality" => "committed",
      "height" => committed_at_height,
      "source" => ^filter_id,
    } = TestWebsocket.recv!(websocket)
    assert {
      :ok,
      %{
        :status => :committed,
        "height" => ^committed_at_height,
        "index" => _,
        "proof" => _,
        "tx" => encoded_tx,
        "tx_result" => %{"code" => 0, "data" => "", "log" => ""}
      } = tx_query_result
    } = API.tx(tx_hash)

    # check consistency of api exposers
    assert {:ok, TestWebsocket.codec(tx_query_result)} == apis_caller.(:tx, %{hash: tx_hash})

    # tx in response can be decoded
    assert encoded_tx |> Base.decode16!() |> HonteD.TxCodec.decode!()

    # TOKEN INFO
    assert {
      :ok,
      %{
        issuer: ^issuer,
        token: ^asset,
        total_supply: @supply
      } = token_info_query_result
    } = API.token_info(asset)

    # check consistency of api exposers
    assert {:ok, TestWebsocket.codec(token_info_query_result)} == apis_caller.(:token_info, %{token: asset})

    # ALLOWS

    {:ok, raw_tx} = API.create_allow_transaction(issuer, bob, "signoff", true)

    # check consistency of api exposers
    assert {:ok, raw_tx} == apis_caller.(
      :create_allow_transaction,
      %{allower: issuer, allowee: bob, privilege: "signoff", allow: true}
    )

    {:ok, _} =
      raw_tx
      |> Transaction.sign(issuer_priv)
      |> API.submit_commit()

    # SIGNOFF

    {:ok, hash} = API.Tools.get_block_hash(send_height)
    {:ok, raw_tx} = API.create_sign_off_transaction(send_height, hash, bob, issuer)
    {:ok, %{committed_in: last_height}} =
      raw_tx
      |> Transaction.sign(bob_priv)
      |> API.submit_commit()

    assert %{
      "transaction" => %{
        "tx" => %{
          "amount" => 5,
          "asset" => ^asset,
          "from" => ^alice,
          "nonce" => 0,
          "to" => ^bob
        },
        "hash" => ^tx_hash
      },
      "finality" => "finalized",
      "height" => _,
      "source" => _,
    } = TestWebsocket.recv!(websocket)

    assert {
      :ok,
      %{
        :status => :finalized,
      }
    } = API.tx(tx_hash)

    # EVENT REPLAYS

    assert {:ok, %{"history_filter" => filter_id}} =
      TestWebsocket.sendrecv!(websocket, :new_send_filter_history, %{watched: bob, first: 1, last: last_height})

    assert %{
      "transaction" => %{
        "tx" => %{
          "amount" => 5,
          "asset" => ^asset,
          "from" => ^alice,
          "nonce" => 0,
          "to" => ^bob
        },
        "hash" => ^tx_hash
      },
      "finality" => "committed",
      "source" => ^filter_id,
      "height" => ^committed_at_height
    } = TestWebsocket.recv!(websocket)
  end

  @tag fixtures: [:tendermint, :apis_caller]
  test "incorrect calls to websockets should return sensible response not crash", %{apis_caller: apis_caller} do
    # bad method
    {:error, %{"data" => %{"method" => "token_inf"}, "message" => "Method not found"}} = apis_caller.(:token_inf, %{token: ""})

    # bad params
    {:error, %{"data" => %{"msg" => "Please provide parameter `token` of type `:binary`",
                           "name" => "token",
                           "type" => "binary"
                         },
               "message" => "Invalid params"}
     } = apis_caller.(:token_info, %{toke: ""})
  end

  ###
  ### contract/tendermint/geth/honted integration
  ###

  deffixture contracts(geth) do
    :ok = geth
    {:ok, token, staking} = Integration.Contract.deploy(30, 10, 1)
    {token, staking}
  end

  @doc """
  Wraps the test in an artificial environment (config.exs-like), which points to a staking contract
  Needs to stop and start some honted applications to reload the fake config
  """
  deffixture staking_contract_config(geth, honted, contracts) do
    :ok = honted # prevent warnings
    :ok = geth
    {_, staking} = contracts

    Application.put_env(:honted_eth, :staking_contract_address, staking)
    Application.put_env(:honted_eth, :enabled, true)

    Application.stop(:honted_eth)
    Application.stop(:honted_abci)
    Application.ensure_all_started(:honted_eth)
    Application.ensure_all_started(:honted_abci)

    on_exit fn ->
      Application.put_env(:honted_eth, :staking_contract_address, "0x0")
      Application.put_env(:honted_eth, :enabled, false)
    end
    :ok
  end

  @tag fixtures: [:geth, :tendermint, :contracts, :staking_contract_config]
  test "Sets validators with staking contract", %{contracts: {token, staking}} do
    # NOTE: for this to work, tendermint must start _after_ the configured, secondary honted start
    #       this magically works, but mind well if it breaks
    amount = 100

    Process.sleep(1200) # need to wait for 1st block
    {:ok, %{"validators" => [%{"pub_key" => %{"data" => start_validator}}]}} = API.Tendermint.RPC.validators(nil)
    # sanity
    assert start_validator != @tm_pubkey

    {:ok, alice_priv} = Crypto.generate_private_key
    {:ok, alice_pub} = Crypto.generate_public_key alice_priv
    {:ok, alice} = Crypto.generate_address alice_pub

    {:ok, [alice_ethereum_address | _]} = Ethereumex.HttpClient.eth_accounts()

    {:ok, _} = Integration.Contract.mint_omg(token, alice_ethereum_address, amount)

    new_validator_pubkey = @tm_pubkey

    {:ok, _} = Integration.Contract.approve(token, alice_ethereum_address, staking, amount)
    {:ok, _} = Integration.Contract.deposit(staking, alice_ethereum_address, amount)
    {:ok, _} = Integration.Contract.join(staking, alice_ethereum_address, new_validator_pubkey)

    {:ok, next} = Eth.Contract.get_next_epoch_block_number(staking)
    HonteD.Integration.WaitFor.eth_block_height(next + 1, true, 10_000)

    Process.sleep(1000) # wait till honted_eth pulls in contract state

    {:ok, raw_tx} = API.create_epoch_change_transaction(alice, 1)

    {:ok, _} =
      raw_tx
      |> Transaction.sign(alice_priv)
      |> API.submit_commit()

    # TODO: this is the proper check for validator set change. Since `validators` endpoint doesn't return the effective
    # validator set, we can't use this now
    # Relevant issue: https://github.com/tendermint/tendermint/issues/1211

    # Process.sleep(5000) # not sure if necessary
    # {:ok, %{"validators" => [validator]}} = API.Tendermint.RPC.validators(nil)
    # assert get_in(validator, ["pub_key", "data"]) == new_validator_pubkey

    # NOTE: temporary way to assert the validator set change - we check if the chain is halted
    #       check that despite time having passed, no blocks get mined
    {:ok, %{"latest_block_height" => last_live_block_height}} = API.Tendermint.RPC.status(nil)
    Process.sleep(1500)
    assert {:ok, %{"latest_block_height" => ^last_live_block_height}} = API.Tendermint.RPC.status(nil)
  end
end
