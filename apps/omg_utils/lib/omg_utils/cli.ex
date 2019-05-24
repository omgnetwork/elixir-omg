# Copyright 2019-2019 OmiseGO Pte Ltd
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

defmodule OMG.Utils.CLI do
  @moduledoc """
  Helper module for working with the command line interface.
  """
  import IO
  import IO.ANSI

  def info(message), do: [:normal, message] |> format |> puts

  def debug(message), do: [:faint, message] |> format |> puts

  def success(message), do: [:green, message] |> format |> puts

  def warn(message), do: [:yellow, message] |> format |> puts

  def error(message, device \\ :stderr) do
    formatted = format([:red, message])
    IO.puts(device, formatted)
  end
end
