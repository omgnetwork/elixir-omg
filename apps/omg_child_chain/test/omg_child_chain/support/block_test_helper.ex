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

defmodule OMG.ChildChain.BlockTestHelper do
  alias OMG.ChildChain.BlockQueue.BlockSubmission

  @child_block_interval 1_000

  def new_block(number) do
    {number,
     %BlockSubmission{
       gas_price: nil,
       hash: "hash_#{number}",
       nonce: 1,
       num: number
     }}
  end

  def get_blocks(end_count, start_count \\ 1, block_interval \\ @child_block_interval) do
    Enum.into(start_count..end_count, %{}, fn i ->
      new_block(i * block_interval)
    end)
  end

  def get_blocks_list(end_count, start_count \\ 1, block_interval \\ @child_block_interval, gas \\ 1) do
    end_count
    |> get_blocks(start_count, block_interval)
    |> Enum.map(fn {_blknum, block} ->
      %{block | gas_price: gas}
    end)
  end
end
