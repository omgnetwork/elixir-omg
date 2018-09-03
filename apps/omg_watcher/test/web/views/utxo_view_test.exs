# Copyright 2018 OmiseGO Pte Ltd
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

defmodule OMG.Watcher.Web.UtxoViewTest do
  @moduledoc false
  use OMG.Watcher.ViewCase

  alias OMG.Watcher.Web.Serializer
  alias OMG.Watcher.Web.View

  test "renders utxo_exit.json with correct response format" do
    utxo_exit = %{
      utxo_pos: 0,
      txbytes: <<>>,
      proof: <<>>,
      sigs: <<>>
    }

    expected = %{
      result: :success,
      data: Serializer.Response.encode16(utxo_exit, [:proof, :sigs, :txbytes])
    }

    assert View.Utxo.render("utxo_exit.json", %{utxo_exit: utxo_exit}) == expected
  end

  test "renders available.json with correct response format" do
    address = <<>>

    utxos = [
      %{
        currency: <<>>,
        amount: 0,
        blknum: 0,
        txindex: 0,
        oindex: 0,
        txbytes: <<>>
      }
    ]

    available = %{
      address: address,
      utxos: utxos
    }

    expected = %{
      result: :success,
      data: %{
        address: address,
        utxos: Serializer.Response.encode16(utxos, [:txbytes, :currency])
      }
    }

    assert View.Utxo.render("available.json", %{available: available}) == expected
  end
end
