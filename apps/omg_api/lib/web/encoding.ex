# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.API.Web.Encoding do
  @moduledoc """
  Provides binary to HEX and reverse encodings.
  NOTE: Intentionally wraps see: `OMG.Eth.Encoding` to keep flexibility for change.
  """

  @doc """
  Encodes raw binary to '0x'-preceded, lowercase HEX string
  """
  @spec to_hex(binary) :: binary
  def to_hex(non_hex), do: OMG.Eth.Encoding.to_hex(non_hex)

  @doc """
  Decodes '0x'-preceded, lowercase HEX string to raw binary, see `to_hex`
  """
  @spec from_hex(binary) :: binary
  def from_hex(encoded), do: OMG.Eth.Encoding.from_hex(encoded)
end
