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

defmodule LoadTest.Ethereum.NonceTracker do
  @moduledoc """
  Nonce tracker for sending ethereum transactions
  """

  alias ExPlasma.Encoding

  def init() do
    :ets.new(:nonce_tracker, [:set, :public, :named_table])
  end

  def get_next_nonce(address) do
    if Enum.empty?(:ets.lookup(:nonce_tracker, address)) do
      current_nonce =
        address
        |> Encoding.to_hex()
        |> Ethereumex.HttpClient.eth_get_transaction_count("pending")
        |> elem(1)
        |> Encoding.to_int()

      # it might happen that this is called more than once, but
      # we relay on :ets.update_counter being atomic, so starting value is not changed
      :ets.update_counter(:nonce_tracker, address, 1, {0, current_nonce - 1})
    else
      :ets.update_counter(:nonce_tracker, address, 1)
    end
  end
end
