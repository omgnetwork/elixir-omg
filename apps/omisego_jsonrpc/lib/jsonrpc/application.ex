defmodule OmiseGO.JSONRPC.Application do
  @moduledoc false

  use Application
  use OmiseGO.API.LoggerExt

  def start(_type, _args) do
    omisego_port = Application.get_env(:omisego_jsonrpc, :omisego_api_rpc_port)

    children = [
      JSONRPC2.Servers.HTTP.child_spec(:http, OmiseGO.JSONRPC.Server.Handler, port: omisego_port)
    ]

    _ = Logger.info(fn -> "Started application OmiseGO.JSONRPC.Application" end)
    opts = [strategy: :one_for_one, name: OmiseGO.JSONRPC.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
