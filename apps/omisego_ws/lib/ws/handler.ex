defmodule OmiseGO.WS.Handler do
  @moduledoc """
  Translates requests flowing from the websocket connection to the auto-exposed API
  """
  require Logger
  alias OmiseGO.API.ExposeSpec.RPCTranslate

  @behaviour :cowboy_websocket_handler

  # WS callbacks

  def init({_tcp, _http}, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_transport_name, req, _opts) do
    {:ok, req, %{api: OmiseGO.API}}
  end

  def websocket_terminate(_reason, _req, _state) do
    :ok
  end

  def websocket_handle({:text, content}, req, state) do
    case decode(content) do
      {:ok, decoded_rq} ->
        id = Map.get(decoded_rq, "id", nil)

        try do
          resp = process_request(decoded_rq, state)
          ws_reply(id, resp, req, state)
        catch
          :throw, {error, data} ->
            ws_reply(id, {error, data}, req, state)
        end

      {:error, :decode_error} ->
        ws_reply(nil, {:invalid_request, {:decode_error, content}}, req, state)
    end
  end

  def websocket_handle({:binary, data}, req, state) do
    _ = Logger.error("websocket got binary frame: #{inspect(data)}, closing")
    {:shutdown, req, state}
  end

  def websocket_info({:event, event}, req, state) do
    {:ok, encoded} = Poison.encode(event)
    {:reply, {:text, encoded}, req, state}
  end

  def websocket_info({:timeout, _pid, msg}, req, state) do
    {:reply, {:text, msg}, req, state}
  end

  def websocket_info(info, req, state) do
    _ = Logger.error("websocket unknown info: #{inspect(info)}")
    {:ok, req, state}
  end

  # RPC+Events protocol handling

  defp ws_reply(id, resp, req, state) do
    {:ok, encoded} =
      resp
      |> wsrpc_response()
      |> put_id(id)
      |> put_version()
      |> Poison.encode()

    {:reply, {:text, encoded}, req, state}
  end

  defp put_id(reply, nil), do: reply
  defp put_id(reply, id), do: Map.put(reply, "id", id)

  defp put_version(reply), do: Map.put(reply, "wsrpc", "1.0")

  defp wsrpc_response({:ok, resp}) do
    %{type: "rs", result: resp}
  end

  defp wsrpc_response({error, data}) when is_atom(error) do
    {code, msg} = error_code_and_message(error)
    %{type: "rs", error: %{code: code, data: data, message: msg}}
  end

  defp error_code_and_message(:parse_error), do: {-32_700, "Parse error"}
  defp error_code_and_message(:invalid_request), do: {-32_600, "Invalid Request"}
  defp error_code_and_message(:method_not_found), do: {-32_601, "Method not found"}
  defp error_code_and_message(:invalid_params), do: {-32_602, "Invalid params"}
  defp error_code_and_message(:internal_error), do: {-32_603, "Internal error"}
  defp error_code_and_message(:server_error), do: {-32_000, "Server error"}

  defp decode(content) do
    case Poison.decode(content) do
      {:ok, decoded_rq} -> {:ok, decoded_rq}
      {:error, _} -> {:error, :decode_error}
      {:error, _, _} -> {:error, :decode_error}
    end
  end

  defp parse(request) when is_map(request) do
    version = Map.get(request, "wsrpc", :undefined)
    method = Map.get(request, "method", :undefined)
    params = Map.get(request, "params", %{})
    type = Map.get(request, "type", :undefined)

    if valid_request?(version, method, params, type) do
      {:rpc, {method, params}}
    else
      :invalid_request
    end
  end

  defp valid_request?(version, method, params, type) do
    version == "1.0" and is_binary(method) and is_map(params) and type == "rq"
  end

  # translation and execution logic

  defp substitute_pid_with_self(_, :pid, _), do: self()
  defp substitute_pid_with_self(_, _, value), do: value

  defp process_request(decoded_rq, %{api: target}) do
    with {:rpc, {method, params}} <- parse(decoded_rq),
         {:ok, fname, args} <- RPCTranslate.to_fa(method, params, target.get_specs(), &substitute_pid_with_self/3) do
      apply_call(target, fname, args)
    end
  end

  defp apply_call(module, fname, args) do
    res = :erlang.apply(module, fname, args)

    case res do
      :ok -> {:ok, :ok}
      {:error, error} -> {:internal_error, error}
      other -> other
    end
  end
end
