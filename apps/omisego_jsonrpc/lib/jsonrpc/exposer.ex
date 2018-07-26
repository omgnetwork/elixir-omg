defmodule OmiseGO.JSONRPC.Exposer do
  @moduledoc """
  This module contains a helper function to be called within JSONRPC Handlers `handle_request`

  It takes the original data request and channels it to a specific API exposed using OmiseGO.API.ExposeSpec

  Internally uses OmiseGO.API.ExposeSpec macro to expose function argument names
  so that pairing between JSON keys and arg names becomes possible.

  Note: it ignores extra args and does not yet handle functions
  of same name but different arity
  """

  use OmiseGO.API.LoggerExt

  @spec handle_request_on_api(method :: binary, params :: %{required(binary) => any}, api :: atom) :: any
  def handle_request_on_api(method, params, api) do
    with {:ok, fname, args} <-
           OmiseGO.API.ExposeSpec.RPCTranslate.to_fa(
             method,
             params,
             api.get_specs(),
             &OmiseGO.JSONRPC.Client.on_match/3
           ),
         {:ok, result} <- apply_call(api, fname, args) do
      OmiseGO.JSONRPC.Client.encode(result)
    else
      # JSONRPC requires to throw whatever fails, for proper handling of jsonrpc errors
      error ->
        throw(error)
    end
  end

  defp apply_call(module, fname, args) do
    case apply(module, fname, args) do
      # NOTE: let's treat all errors in the called API as internal errors, this seems legit
      {:ok, any} ->
        {:ok, any}

      {:error, any} ->
        {:internal_error, any}
    end
  end
end
