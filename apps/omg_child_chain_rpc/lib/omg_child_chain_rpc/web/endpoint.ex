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

defmodule OMG.ChildChainRPC.Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :omg_child_chain_rpc
  use Sentry.Phoenix.Endpoint
  # use OMG.ChildChainRPC.Plugs.Counter

  plug(Plug.RequestId)
  plug(Plug.Logger, log: :debug)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  if Application.get_env(:omg_child_chain_rpc, OMG.ChildChainRPC.Web.Endpoint)[:enable_cors],
    do: plug(CORSPlug)

  plug(OMG.ChildChainRPC.Web.Router)
end
