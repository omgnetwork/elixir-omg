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

# FIXME
defmodule OMG.Watcher.Web.View.ChallengeTest do
  @moduledoc false

  use OMG.Watcher.ViewCase

  alias OMG.Watcher.Web.View

  test "renders challenge.json with correct response format" do
    challenge = %{
      cutxopos: 0,
      eutxoindex: 0,
      txbytes: "0",
      proof: "0",
      sigs: "0"
    }

    expected = %{
      result: :success,
      data: challenge
    }

    assert View.Challenge.render("challenge.json", %{challenge: challenge}) == expected
  end
end
