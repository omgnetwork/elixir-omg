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

defmodule OMG.Eth.Blockchain.PrivateKey do
  @moduledoc """
  Extracts private key from environment
  """
  require Integer

  def get() do
    private_key = System.get_env("PRIVATE_KEY")
    maybe_hex(private_key)
  end

  @spec maybe_hex(String.t() | nil) :: binary() | nil
  defp maybe_hex(hex_data, type \\ :raw)
  defp maybe_hex(nil, _), do: nil
  defp maybe_hex(hex_data, :raw), do: load_raw_hex(hex_data)

  @spec load_raw_hex(String.t()) :: binary()
  defp load_raw_hex("0x" <> hex_data), do: load_raw_hex(hex_data)

  defp load_raw_hex(hex_data) when Integer.is_odd(byte_size(hex_data)),
    do: load_raw_hex("0" <> hex_data)

  defp load_raw_hex(hex_data) do
    Base.decode16!(hex_data, case: :mixed)
  end
end
