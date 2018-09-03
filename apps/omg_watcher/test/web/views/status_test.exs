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

defmodule OMG.Watcher.Web.View.StatusTest do
  @moduledoc false
  use OMG.Watcher.ViewCase

  alias OMG.Watcher.Web.View

  test "renders status.json with correct response format" do
    status = %{
      last_validated_child_block_number: 0,
      last_mined_child_block_number: 0,
      last_mined_child_block_timestamp: 0,
      eth_syncing: true
    }

    expected = %{
      result: :success,
      data: status
    }

    assert View.Status.render("status.json", %{status: status}) == expected
  end
end
