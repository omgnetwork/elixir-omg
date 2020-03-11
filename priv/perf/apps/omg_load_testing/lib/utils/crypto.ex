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
# limitation

defmodule OMG.LoadTesting.Utils.Crypto do
  @moduledoc false

  @type hash_t() :: <<_::256>>
  @type priv_key_t :: <<_::256>>

  @doc """
  Produces a KECCAK digest for the message.

  see https://hexdocs.pm/exth_crypto/ExthCrypto.Hash.html#kec/0

  ## Example

    iex> OMG.LoadTesting.Utils.Crypto.hash("omg!")
    <<241, 85, 204, 147, 187, 239, 139, 133, 69, 248, 239, 233, 219, 51, 189, 54,
      171, 76, 106, 229, 69, 102, 203, 7, 21, 134, 230, 92, 23, 209, 187, 12>>
  """
  @spec hash(binary) :: hash_t()
  def hash(message), do: ExthCrypto.Hash.hash(message, ExthCrypto.Hash.kec())

  @doc """
  Generates private key. Internally uses OpenSSL RAND_bytes. May throw if there is not enough entropy.
  """
  @spec generate_private_key() :: {:ok, priv_key_t()}
  def generate_private_key, do: {:ok, :crypto.strong_rand_bytes(32)}
end
