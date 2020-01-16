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

defmodule OMG.Eth.RootChain.SubmitBlock do
  @moduledoc """
  Interface to contract block submission.
  """
  alias OMG.Eth.Blockchain.PrivateKey
  alias OMG.Eth.Encoding
  alias OMG.Eth.Transaction

  @type address :: <<_::160>>
  @type hash :: <<_::256>>

  @spec submit(
          atom(),
          binary(),
          pos_integer(),
          pos_integer(),
          OMG.Eth.address(),
          OMG.Eth.address()
        ) ::
          {:error, binary() | atom() | map()}
          | {:ok, <<_::256>>}
  def submit(backend, hash, nonce, gas_price, from, contract) do
    # NOTE: we're not using any defaults for opts here!
    contract_transact(
      backend,
      from,
      contract,
      "submitBlock(bytes32)",
      [hash],
      nonce: nonce,
      gasPrice: gas_price,
      value: 0,
      gas: 100_000
    )
  end

  @spec contract_transact(atom(), address, address, binary, [any], keyword) :: {:ok, hash()} | {:error, any}
  defp contract_transact(:infura = backend, _from, to, signature, args, opts) do
    abi_encoded_data = ABI.encode(signature, args)
    [nonce: nonce, gasPrice: gas_price, value: value, gas: gas_limit] = opts
    private_key = PrivateKey.get()

    transaction_data =
      %OMG.Eth.Blockchain.Transaction{
        data: abi_encoded_data,
        gas_limit: gas_limit,
        gas_price: gas_price,
        init: <<>>,
        nonce: nonce,
        to: to,
        value: value
      }
      |> OMG.Eth.Blockchain.Transaction.Signature.sign_transaction(private_key)
      |> OMG.Eth.Blockchain.Transaction.serialize()
      |> ExRLP.encode()
      |> Base.encode16(case: :lower)

    Transaction.send(backend, "0x" <> transaction_data)
  end

  defp contract_transact(backend, from, to, signature, args, opts) do
    data = encode_tx_data(signature, args)

    txmap =
      %{from: Encoding.to_hex(from), to: Encoding.to_hex(to), data: data}
      |> Map.merge(Map.new(opts))
      |> encode_all_integer_opts()

    Transaction.send(backend, txmap)
  end

  defp encode_tx_data(signature, args) do
    signature
    |> ABI.encode(args)
    |> Encoding.to_hex()
  end

  defp encode_all_integer_opts(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> is_integer(v) end)
    |> Enum.into(opts, fn {k, v} -> {k, Encoding.to_hex(v)} end)
  end
end
