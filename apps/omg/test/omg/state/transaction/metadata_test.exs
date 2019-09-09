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

defmodule OMG.State.Transaction.MetadataTest do
  use ExUnit.Case, async: true
  import OMG.State.Transaction.Metadata, only: [is_metadata?: 1]

  test "if guard returns false on byte size larger then 32" do
    assert false == is_metadata?(<<0::size(264)>>)
  end

  test "if guard returns true on byte size 32" do
    assert true == is_metadata?(<<0::size(256)>>)
  end

  test "if guard returns true on nil as argument" do
    assert true == is_metadata?(nil)
  end

  test "if guard refuses bitstrings" do
    assert false == is_metadata?(<<1::2>>)
  end
end
