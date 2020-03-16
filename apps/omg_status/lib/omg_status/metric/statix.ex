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
defmodule OMG.Status.Metric.Statix do
  @moduledoc """
  Useful for overwritting Statix behaviour.
  """
  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Statix
      def connect(), do: :ok

      def increment(_), do: :ok
      def increment(_, _, options \\ []), do: :ok

      def decrement(_, val \\ 1, options \\ []), do: :ok

      def gauge(_, val, options \\ []), do: :ok

      def histogram(_, val, options \\ []), do: :ok

      def timing(_, val, options \\ []), do: :ok

      def measure(key, options \\ [], fun), do: :ok

      def set(key, val, options \\ []), do: :ok

      def event(key, val, options), do: :ok

      def service_check(key, val, options), do: :ok

      def current_conn(), do: %Statix.Conn{sock: __MODULE__}
    end
  end
end
