# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.ChildChainRPC.Web.Controller.Transaction do
  @moduledoc """
  Provides endpoint action to submit transaction to the Child Chain.
  """

  use OMG.ChildChainRPC.Web, :controller

  alias OMG.ChildChainRPC.Web.View

  @api_module Application.fetch_env!(:omg_child_chain_rpc, :child_chain_api_module)

  def submit(conn, params) do
    with {:ok, txbytes} <- expect(params, "transaction", :hex),
         {:ok, details} <- apply(@api_module, :submit, [txbytes]) do
      conn
      |> put_view(View.Transaction)
      |> render(:submit, result: details)
    end
    |> increment_metrics_counter()
  end

  defp increment_metrics_counter(response) do
    # this should go away with spandex
    case response do
      {:error, {:validation_error, _, _}} -> :telemetry.execute([:transaction], %{counter: 1}, %{valid: :failed})
      %Plug.Conn{} -> :telemetry.execute([:transaction], %{counter: 1}, %{valid: :succeed})
      _ -> :telemetry.execute([:transaction], %{counter: 1}, %{valid: :"failed.unidentified"})
    end

    response
  end
end
