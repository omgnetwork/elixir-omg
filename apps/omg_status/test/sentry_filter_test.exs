# Copyright 2019-2020 OMG Network Pte Ltd
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

defmodule OMG.Status.SentryFilterTest do
  use ExUnit.Case, async: true

  test "excludes exception properly" do
    # ignore excluded exception
    assert_raise(
      Phoenix.NotAcceptableError,
      fn ->
        raise Phoenix.NotAcceptableError,
              "Could not render \"406.json\" for OMG.WatcherRPC.Web.Views.Error, please define a matching clause for render/2 or define a template at \"lib/omg_watcher_rpc_web/templates/views/error/*\". No templates were compiled for this module."
      end
    )

    assert Sentry.capture_exception(
             %Phoenix.NotAcceptableError{plug_status: 406},
             event_source: :plug,
             result: :sync
           ) == :excluded
  end
end
