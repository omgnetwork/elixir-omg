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
defmodule Itest.ApiModel.ChallengeData do
  @moduledoc """
  The purpose of this module is to represent a specific API response as a struct and validates it's response and validates it's response
  """

  defstruct [:exit_id, :exiting_tx, :input_index, :sig, :txbytes]

  @type t() :: %__MODULE__{
          exit_id: pos_integer(),
          exiting_tx: binary(),
          input_index: non_neg_integer(),
          sig: binary(),
          txbytes: binary
        }

  def to_struct(attrs) do
    struct = struct(__MODULE__)

    result =
      Enum.reduce(Map.to_list(struct), struct, fn {k, _}, acc ->
        case Map.fetch(attrs, Atom.to_string(k)) do
          {:ok, v} -> %{acc | k => v}
          :error -> acc
        end
      end)

    true = is_valid(result)
    result
  end

  defp is_valid(struct) do
    is_integer(struct.exit_id) &&
      is_binary(struct.exiting_tx) &&
      is_integer(struct.input_index) &&
      is_binary(struct.sig) &&
      is_binary(struct.txbytes)
  end
end
