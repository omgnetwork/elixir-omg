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

defmodule OMG.Watcher.Web.Serializer.ResponseTest do
  use ExUnit.Case, async: true

  alias OMG.Watcher.Web.Serializer

  test "encode16/decode16 funciton encodes/decodes only specified fields" do
    decoded_map = %{"key_1" => "value_1", "key_2" => "value_2", "key_3" => "value_3"}

    encoded_map = Serializer.Response.encode16(decoded_map, ["key_2"])

    assert decoded_map == Serializer.Response.decode16(encoded_map, ["key_2"])
  end

  test "encode16/decode16 funciton encodes/decodes list of maps with only specified fields" do
    decoded_map = %{"key_1" => "value_1", "key_2" => "value_2", "key_3" => "value_3"}
    decoded_list = [decoded_map, decoded_map]

    encoded_list = Serializer.Response.encode16(decoded_list, ["key_2"])

    assert decoded_list == Serializer.Response.decode16(encoded_list, ["key_2"])
  end

  test "encode16/decode16 funciton called with empty map/list returns empty map/list" do
    assert %{} == Serializer.Response.encode16(%{}, ["key_2"])
    assert [%{}] == Serializer.Response.encode16([%{}], ["key_2"])

    assert %{} == Serializer.Response.decode16(%{}, ["key_2"])
    assert [%{}] == Serializer.Response.decode16([%{}], ["key_2"])
  end

  test "encode16/decode16 funciton called with none fields returns same map/list" do
    map = %{"key_1" => "value_1", "key_2" => "value_2", "key_3" => "value_3"}
    list = [map, map]

    assert map == Serializer.Response.encode16(map, [])
    assert list == Serializer.Response.encode16(list, [])

    assert map == Serializer.Response.decode16(map, [])
    assert list == Serializer.Response.decode16(list, [])
  end


  test "encode16/decode16 funciton called with field which containts nil value" do
    map = %{"key_1" => "value_1", "key_2" => nil, "key_3" => "value_3"}
    list = [map, map]

    assert map == Serializer.Response.encode16(map, ["key_2"])
    assert list == Serializer.Response.encode16(list, ["key_2"])

    assert map == Serializer.Response.decode16(map, ["key_2"])
    assert list == Serializer.Response.decode16(list, ["key_2"])
  end

end
