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
defmodule OMG.Utils.RemoteIP do
  @moduledoc """
  This plug sets remote_ip from CF-Connecting-IP header.
  """
  import Plug.Conn

  @header_name "cf-connecting-ip"

  def init(options), do: options

  def call(conn, _opts) do
    ips = get_req_header(conn, @header_name)

    parse_and_set_ip(conn, ips)
  end

  defp parse_and_set_ip(conn, [forwarded_ips]) when is_binary(forwarded_ips) do
    left_ip =
      forwarded_ips
      |> String.split(",")
      |> List.first()

    parse_ip(conn, left_ip)
  end

  defp parse_and_set_ip(conn, _ip), do: conn

  defp parse_ip(conn, ip_string) when is_binary(ip_string) do
    parsed_ip =
      ip_string
      |> String.trim()
      |> String.to_charlist()
      |> :inet.parse_address()

    case parsed_ip do
      {:ok, ip} -> %{conn | remote_ip: ip}
      _ -> conn
    end
  end

  defp parse_ip(conn, _), do: conn
end
