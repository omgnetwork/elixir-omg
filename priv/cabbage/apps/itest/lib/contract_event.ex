defmodule Itest.ContractEvent do
  @moduledoc """
  Listens for contract events passed in as `listen_to`.
  """
  use WebSockex
  alias Itest.Transactions.Encoding
  @subscription_id 1

  require Logger
  #
  # Client API
  #

  @doc """
  Starts a GenServer that listens to events.
  """
  @spec start_link(Keyword.t()) :: {:ok, pid()} | no_return()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    case Process.whereis(name) do
      nil ->
        websockex_start_link(name, opts)

      pid ->
        {:ok, pid}
    end
  end

  #
  # Server API
  #

  @doc false
  @impl true
  def handle_frame({:text, msg}, state) do
    {:ok, decoded} = Jason.decode(msg)

    case decoded["params"]["result"] do
      nil ->
        :ok

      result ->
        # parsing events
        # per spec, they have 4 topics and data field
        topics = result["topics"]

        case Enum.count(topics) do
          4 ->
            abi = Keyword.fetch!(state, :abi)

            event =
              ABI.Event.find_and_decode(
                abi,
                Encoding.to_binary(Enum.at(topics, 0)),
                Encoding.to_binary(Enum.at(topics, 1)),
                Encoding.to_binary(Enum.at(topics, 2)),
                Encoding.to_binary(Enum.at(topics, 3)),
                Encoding.to_binary(result["data"])
              )

            Kernel.send(Keyword.fetch!(state, :subscribe), {:event, event})
            _ = Logger.info("Event detected: #{inspect(event)}")

          _ ->
            :ok
        end
    end

    {:ok, state}
  end

  defp websockex_start_link(name, opts) do
    ws_url = Keyword.fetch!(opts, :ws_url)
    abi_path = Keyword.fetch!(opts, :abi_path)

    abi =
      abi_path
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("abi")
      |> ABI.parse_specification(include_events?: true)

    case WebSockex.start_link(ws_url, __MODULE__, [{:abi, abi} | opts], name: name) do
      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:ok, pid} ->
        spawn(fn -> listen(pid, opts) end)
        {:ok, pid}
    end
  end

  # >> {"id": 1, "method": "eth_subscribe", "params": ["logs",
  #  {"address": "0x8320fe7702b96808f7bbc0d4a888ed1468216cfd",
  # "topics": ["0xd78a0cb8bb633d06981248b816e7bd33c2a35a6089241d099fa519e361cab902"]}]}
  defp listen(pid, opts) do
    payload = %{
      jsonrpc: "2.0",
      id: @subscription_id,
      method: "eth_subscribe",
      params: [
        "logs",
        Keyword.fetch!(opts, :listen_to)
      ]
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(payload)})
  end
end
