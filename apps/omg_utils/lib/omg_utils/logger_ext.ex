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

defmodule OMG.Utils.LoggerExt do
  @moduledoc """
  Module provides extenssion point over default logging functionality. However we allow changes only in development
  environment for debugging purposes. No changes to this module can be committed to the main branch ever!

  We assume all logging functionality in application code is provided only by this module. We want to keep logging
  impossible to break application, therefore we based it on standard Logger module. Keep it simple and stupid.

  Four logging levels are understanded as follows:
   * error - use when application is about to crash to provide specific failure reason
   * warn  - something went bad and might cause application to crash, e.g. misconfiguration
   * info  - logs most important, not frequent, concise messages, e.g. modules starting. Enabled for production env.
   * debug - most likely default option for everything but above.

  We assume that the logged message:
   * is logged in lazy way (you shall provide function not a string to the Logger function)
   * is single-lined, so does not use witespaces other than space (?\s)
   * all string interpolated data are inspected ("... \#{inspect data} ...")

  Please help us keep logging as simple and borring as possible
  """

  defmacro __using__(_opt) do
    quote do
      require Logger

      # Uncommenting following code with replace Kernel.inspect/1 function with your own implementation.
      # Before uncommenting please ensure no changes will be committed to the main branch (e.g add fix-me).

      # import Kernel, except: [inspect: 1]
      # def inspect(term) do
      #   Kernel.inspect(term, pretty: true, width: 40, limit: :infinity)
      # end
    end
  end
end
