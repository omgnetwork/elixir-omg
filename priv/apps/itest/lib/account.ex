defmodule Itest.Account do
  @moduledoc """
    Maintaining used accounts state so that we're able to run tests multiple times.
  """
  use GenServer
  alias Itest.Transactions.Currency
  @accounts_path "../data/ganache/data/account_keys.txt"
  @accounts_state '/tmp/used_accounts'

  @vault "0x0433420DEE34412B5Bf1e29FBf988aD037cc5Db7"
  def vault(), do: @vault

  @plasma_framework "0x9fA1F748AdEad1F26667a6ddF748669eDB02c70d"
  def plasma_framework(), do: @plasma_framework

  @ether_vault_id 1
  def vault_id(currency) do
    ether = Currency.ether()

    case currency do
      ^ether -> @ether_vault_id
    end
  end

  @spec take_accounts(integer()) :: map()
  def take_accounts(number_of_accounts) do
    :ok = ensure_started()
    GenServer.call(__MODULE__, {:take_accounts, number_of_accounts})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    eth_accounts = Jason.decode!(File.read!(@accounts_path))
    {:ok, dets_ref} = :dets.open_file(:used_accounts, [{:file, @accounts_state}])

    # for the inital setup we first eliminate two accounts because they're
    # used by childchain and contract deployments so we start with the third one
    case :dets.lookup(dets_ref, :counter) do
      [] ->
        starting_index = 3
        :ok = :dets.insert(dets_ref, {:counter, starting_index})

      [counter: count] ->
        count
    end

    {:ok, %{eth_accounts: eth_accounts, dets_ref: dets_ref}}
  end

  @doc """
    Keys from Ganache are in form:
    "addresses" => %{
    "0xa9f913312b7ec75f755c4f3edb6e2bbd3526b918" => %{
      "account" => %{
        "balance" => "0x152d02c7e14af6800000",
        "codeHash" => "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
        "nonce" => "0x",
        "stateRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"
      },
      "address" => "0xa9f913312b7ec75f755c4f3edb6e2bbd3526b918",
      "publicKey" => %{
        "data" => [174, ...],
        "type" => "Buffer"
      },
      "secretKey" => %{
        "data" => [196, ...],
        "type" => "Buffer"
      }
    },
   "private_keys" => %{
    "0xa9f913312b7ec75f755c4f3edb6e2bbd3526b918" => "c41183263da1c5aab3df07d917b6010b466008361d3549abf0f1a8198e13be0d",
    "0xd74485a6600d8de95d84d5e1747480c528df1f9a" => "3a82e7bec989f2e92d5e059dbaa56c90018c2bc419e0a2b8cbcc0ddfd3c2fbdd",
    "0xa8ba9dea29234be7504fae477d2f6b1fd1078d46" => "e178ea48be504a63b01df495a14200c13fa361154b4edd128ce7772d43017712"}
  """
  def handle_call(
        {:take_accounts, number_of_accounts},
        _from,
        %{eth_accounts: eth_accounts, dets_ref: dets_ref} = state
      ) do
    index =
      case :dets.lookup(dets_ref, :counter) do
        [] -> 0
        [counter: count] -> count
      end

    last_index = index + number_of_accounts
    # write down which accounts we took and sync to disk immediately
    :ok = :dets.insert(dets_ref, {:counter, last_index})
    :ok = :dets.sync(dets_ref)
    accounts = Enum.slice(eth_accounts["private_keys"], last_index, number_of_accounts)
    {:reply, {:ok, accounts}, state}
  end

  def terminate(_, %{dets_ref: dets_ref}) do
    :dets.close(dets_ref)
  end

  defp ensure_started() do
    case __MODULE__.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end
end
