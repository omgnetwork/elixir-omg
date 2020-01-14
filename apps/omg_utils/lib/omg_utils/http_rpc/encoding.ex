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

defmodule OMG.Utils.HttpRPC.Encoding do
  @moduledoc """
  Provides binary to HEX and reverse encodings.
  NOTE: Intentionally wraps see: `OMG.Eth.Encoding` to keep flexibility for change.
  """

  @doc """
  Encodes raw binary to '0x'-preceded, lowercase HEX string
  """
  # because https://github.com/rrrene/credo/issues/583, we need to:
  # credo:disable-for-next-line Credo.Check.Consistency.SpaceAroundOperators
  @spec to_hex(binary()) :: <<_::16, _::_*8>>
  def to_hex(binary), do: "0x" <> Base.encode16(binary, case: :lower)

  @doc """
  Decodes '0x'-preceded, lowercase HEX string to raw binary, see `to_hex`
  """
  # because https://github.com/rrrene/credo/issues/583, we need to:
  # credo:disable-for-next-line Credo.Check.Consistency.SpaceAroundOperators
  @spec from_hex(<<_::16, _::_*8>>) :: {:ok, binary()} | {:error, :invalid_hex}
  def from_hex("0x" <> hexstr), do: Base.decode16(hexstr, case: :mixed)
  def from_hex(_), do: {:error, :invalid_hex}
end
