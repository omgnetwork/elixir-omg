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

defmodule OMG.ChildChain.ReleaseTasks.SetApplicationTest do
  use ExUnit.Case, async: true
  alias OMG.ChildChain.ReleaseTasks.SetApplication

  @app :omg_child_chain

  test "if release name and version are set correctly" do
    release_set = :yolo
    current_version_set = 1
    config = SetApplication.load([], release: release_set, current_version: current_version_set)
    release = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:release)
    current_version = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:current_version)
    assert release == release_set
    assert current_version == current_version_set
  end
end
