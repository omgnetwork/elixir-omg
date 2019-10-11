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

defmodule OMG.ChildChain.FakeRootChain do
  @moduledoc """
  A very simple module used to test the submit function in
  the BlockQueueSubmitter module.
  """

  def get_mined_child_block, do: {:ok, 10}

  def submit_block("success", _nonce, _gas_price), do: {:ok, "txhash"}

  def submit_block("nonce_too_low", _nonce, _gas_price) do
    {:error, %{"code" => -32_000, "message" => "nonce too low"}}
  end
end
