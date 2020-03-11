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

defmodule LoadTesting.Utils.Account do
  @moduledoc """
  Utility module for utxo
  """

  @doc """
  Repeats f until f returns {:ok, ...}, :ok OR exception is raised (see :erlang.exit,:erlang.error) OR timeout
  after `timeout` milliseconds specified

  Simple throws and :badmatch are treated as signals to repeat
  """
  require Logger

  alias ExPlasma.Encoding
  alias LoadTesting.Utils.Crypto

  @type private_key_t :: <<_::256>>
  @type private_key_hex_t :: <<_::512>> | <<_::528>>
  @type public_key_t :: <<_::512>>
  @type addr_t :: <<_::160>>
  @type t :: %__MODULE__{
          priv: private_key_t(),
          pub: public_key_t(),
          addr: addr_t()
        }

  defstruct [:priv, :pub, :addr]

  @spec new(private_key_t()) :: t()
  def new(private_key) when byte_size(private_key) == 32 do
    {:ok, der_public_key} = compute_public_key(private_key)
    public_key = der_to_raw(der_public_key)
    {:ok, address} = compute_address(public_key)
    struct!(__MODULE__, priv: private_key, pub: public_key, addr: address)
  end

  @spec new(private_key_hex_t()) :: t()
  def new(private_key_hex), do: Encoding.to_binary(private_key_hex) |> new()

  @spec new() :: t()
  def new() do
    {:ok, priv} = Crypto.generate_private_key()
    new(priv)
  end

  defp compute_public_key(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  defp compute_address(<<pub::binary-size(64)>>) do
    <<_::binary-size(12), address::binary-size(20)>> = Crypto.hash(pub)
    {:ok, address}
  end

  defp der_to_raw(<<4::integer-size(8), data::binary>>), do: data
end
