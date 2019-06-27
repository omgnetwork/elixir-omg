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

defmodule OMG.WatcherRPC.Web.Validator.TypedDataSigned do
  @moduledoc """
  Validates `/transaction.submit_typed` request body.
  """

  alias OMG.State.Transaction
  import OMG.Utils.HttpRPC.Validator.Base

  @signature_length 65

  @doc """
  Parses and validates request body
  """
  @spec parse(map()) :: {:ok, Transaction.Signed} | {:error, any()}
  def parse(params) do
    with :ok <- params |> Map.get("domain") |> parse_domain(),
         {:ok, sigs} <- expect(params, "signatures", :list),
         {:ok, sigs} <- parse_signatures(sigs),
         :ok <- params |> Map.get("message") |> parse_transaction(),
         do: :nothing

    :implement_me
  end

  def parse_transaction(message) when is_map(message) do
    :implement_me
  end

  # TODO: make expect(:map) or ensure_type(:map | :list | :nonempty_list) ...
  ## or ensure(params, key, type, parse_function)
  # defp parse_transaction(_), do: error("message", :missing)

  def parse_domain(map) when is_map(map) do
    :implement_me
  end

  @spec ensure_network_match(map(), map()) :: :ok | {:error, any()}
  def ensure_network_match(domain_from_params, network_domain \\ nil) do
    :implement_me
  end

  # TODO: defp parse_domain(_), do: error("domain", :missing)

  def parse_signatures(sigs) when is_list(sigs) do
    sigs
    |> Enum.map(&signature_or_error/1)
    |> Enum.split_with(&is_binary/1)
    |> case do
      {valid_sigs, []} -> {:ok, valid_sigs}
      {_, [err | _]} -> err
    end
  end

  defp signature_or_error(sig) do
    with {:ok, sig} <- expect(%{"signature" => sig}, "signature", [:hex, length: @signature_length]),
         do: sig
  end
end
