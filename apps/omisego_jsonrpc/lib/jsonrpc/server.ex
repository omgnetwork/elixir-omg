defmodule OmiseGO.JSONRPC.Server.Handler do
  @moduledoc """
  Exposes OmiseGO.API via jsonrpc 2.0 over HTTP. It leverages the generic OmiseGO.JSONRPC.Exposer convenience module

  Only handles the integration with the JSONRPC2 package
  """
  use JSONRPC2.Server.Handler

  def handle_request(method, params) do
    IO.puts("handle_request <<")
    OmiseGO.JSONRPC.Exposer.handle_request_on_api(method, params, OmiseGO.API)
  end
end
