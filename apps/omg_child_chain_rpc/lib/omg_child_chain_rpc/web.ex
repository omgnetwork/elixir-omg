# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.ChildChainRPC.Web do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use OMG.ChildChainRPC.Web, :controller
      use OMG.ChildChainRPC.Web, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: OMG.ChildChainRPC.Web

      import Plug.Conn
      import OMG.Utils.HttpRPC.Validator.Base
      alias OMG.ChildChainRPC.Web.Router.Helpers, as: Routes

      action_fallback(OMG.ChildChainRPC.Web.Controller.Fallback)
      use SpandexPhoenix, tracer: OMG.ChildChainRPC.Tracer

      @doc """
      Passes result to the render process when successful or returns error result unchanged.
      Error tuple will be passed to the see: `OMG.WatcherRPC.Web.Controller.Fallback`
      """
      def api_response(api_result, conn, template) when is_tuple(api_result),
        do: with({:ok, data} <- api_result, do: api_response(data, conn, template))

      @doc """
      Takes advantage of preset api response structure and module names conventions to discover parameters
      to Phoenix Controller's [render/3](https://hexdocs.pm/phoenix/Phoenix.Controller.html#render/3)
      """
      def api_response(data, conn, template) do
        view_module =
          conn
          |> controller_module()
          |> Atom.to_string()
          |> String.replace("Controller", "View")
          |> String.to_existing_atom()

        conn
        |> put_view(view_module)
        |> render(template, response: data, app_infos: conn.assigns.app_infos)
      end
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/omg_child_chain_rpc_web/templates",
        namespace: OMG.ChildChainRPC.Web
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
