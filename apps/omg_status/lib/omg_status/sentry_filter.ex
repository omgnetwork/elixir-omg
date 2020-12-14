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

defmodule OMG.Status.SentryFilter do
  @moduledoc """
  Sentry callback for filtering events.
  """
  @behaviour Sentry.EventFilter

  # when the development environment restarts it lacks network access
  # something to do with Cloud DNS
  def exclude_exception?(%MatchError{term: {:error, :nxdomain}}, _), do: true

  # Ignoring 406 status code invalid headers exception
  def exclude_exception?(%Phoenix.NotAcceptableError{plug_status: 406}, _), do: true

  def exclude_exception?(%Plug.Parsers.RequestTooLargeError{}, _), do: true

  def exclude_exception?(%CaseClauseError{term: {:error, :econnrefused}}, _), do: true

  def exclude_exception?(_, _), do: false
end
