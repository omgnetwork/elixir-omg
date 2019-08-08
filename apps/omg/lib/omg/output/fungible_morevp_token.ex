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

defmodule OMG.Output.FungibleMoreVPToken do
  @moduledoc """
  Representation of the payment transaction output of a fungible token `currency`
  """
  alias OMG.Crypto
  defstruct [:owner, :currency, :amount]

  @type t :: %__MODULE__{
          owner: Crypto.address_t(),
          currency: Crypto.address_t(),
          amount: non_neg_integer()
        }
end

defimpl OMG.Output, for: OMG.Output.FungibleMoreVPToken do
  alias OMG.Output.FungibleMoreVPToken

  @doc """
  For payment outputs, a binary witness is assumed to be a signature equal to the payment's output owner
  """
  def can_spend?(%FungibleMoreVPToken{owner: owner}, witness, _raw_tx) when is_binary(witness) do
    owner == witness
  end

  def is_zero?(%FungibleMoreVPToken{amount: 0}), do: false
  def is_zero?(%FungibleMoreVPToken{amount: _}), do: true

  # NOTE: we have no migrations, so we handle data compatibility here (make_db_update/1 and from_db_kv/1), OMG-421
  def to_db_value(%FungibleMoreVPToken{owner: owner, currency: currency, amount: amount})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) do
    %{owner: owner, currency: currency, amount: amount}
  end

  def from_db_value(%FungibleMoreVPToken{}, %{owner: owner, currency: currency, amount: amount})
      when is_binary(owner) and is_binary(currency) and is_integer(amount) do
    %FungibleMoreVPToken{owner: owner, currency: currency, amount: amount}
  end
end
