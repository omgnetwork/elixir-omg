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

defmodule OMG.API.Config do

  def get_overloaded_env_var(app, config_key, var_name, default \\ nil) when is_binary(var_name) do
    default = Application.get_env(app, config_key, default)
    case :os.getenv(String.to_charlist(var_name)) do
      false -> default
      value_set_in_env -> List.to_string(value_set_in_env)
    end
  end

end
