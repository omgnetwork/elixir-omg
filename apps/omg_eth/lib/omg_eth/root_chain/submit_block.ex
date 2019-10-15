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

defmodule OMG.Eth.RootChain.SubmitBlock do
  @moduledoc """
  Interface to contract block submission.
  """
  alias OMG.Eth

  @spec submit(
          binary(),
          pos_integer(),
          pos_integer(),
          OMG.Eth.address(),
          OMG.Eth.address()
        ) ::
          {:error, binary() | atom() | map()}
          | {:ok, <<_::256>>}
  def submit(hash, nonce, gas_price, from, contract) do
    # NOTE: we're not using any defaults for opts here!
    Eth.contract_transact(
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
end
