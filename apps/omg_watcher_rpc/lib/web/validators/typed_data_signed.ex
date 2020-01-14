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

defmodule OMG.WatcherRPC.Web.Validator.TypedDataSigned do
  @moduledoc """
  Validates `/transaction.submit_typed` request body.
  """

  alias OMG.State.Transaction
  alias OMG.TypedDataHash.Tools
  alias OMG.Utils.HttpRPC.Validator.Base
  import OMG.Utils.HttpRPC.Validator.Base

  @doc """
  Parses and validates request body for /transaction.submit_typed`
  """
  @spec parse(map()) :: {:ok, Transaction.Signed.t()} | {:error, any()}
  def parse(params) do
    with {:ok, domain} <- expect(params, "domain", map: &parse_domain/1),
         :ok <- ensure_network_match(domain),
         {:ok, sigs} <- expect(params, "signatures", list: &to_signature/1),
         {:ok, raw_tx} <- parse_transaction(params) do
      {:ok, %Transaction.Signed{raw_tx: raw_tx, sigs: sigs}}
    end
  end

  @spec parse_transaction(map()) :: {:ok, Transaction.Payment.t()} | {:error, any}
  def parse_transaction(params) do
    with {:ok, msg} <- expect(params, "message", :map),
         inputs when is_list(inputs) <- parse_inputs(msg),
         outputs when is_list(outputs) <- parse_outputs(msg),
         {:ok, metadata} <- expect(msg, "metadata", :hash) do
      {:ok, Transaction.Payment.new(inputs, outputs, metadata)}
    end
  end

  @spec parse_domain(map()) :: {:ok, Tools.eip712_domain_t()} | Base.validation_error_t()
  def parse_domain(map) when is_map(map) do
    with name = Map.get(map, "name"),
         version = Map.get(map, "version"),
         {:ok, salt} <- expect(map, "salt", :hash),
         {:ok, contract} <- expect(map, "verifyingContract", :address),
         do: {:ok, %{name: name, version: version, salt: salt, verifyingContract: contract}}
  end

  @spec ensure_network_match(Tools.eip712_domain_t(), Tools.eip712_domain_t() | nil) :: :ok | Base.validation_error_t()
  def ensure_network_match(domain_from_params, network_domain \\ nil) do
    network_domain =
      case network_domain do
        nil -> OMG.TypedDataHash.Config.domain_separator_from_config()
        params when is_map(params) -> Tools.domain_separator(params)
      end

    if network_domain == Tools.domain_separator(domain_from_params),
      do: :ok,
      else: error("domain", :domain_separator_mismatch)
  end

  @spec to_signature(binary()) :: {:ok, <<_::520>>} | Base.validation_error_t()
  defp to_signature(sig_str), do: expect(%{"signature" => sig_str}, "signature", :signature)

  @spec parse_input(map()) :: {:ok, {integer(), integer(), integer()}} | Base.validation_error_t()
  defp parse_input(input) do
    with {:ok, blknum} <- expect(input, "blknum", :non_neg_integer),
         {:ok, txindex} <- expect(input, "txindex", :non_neg_integer),
         {:ok, oindex} <- expect(input, "oindex", :non_neg_integer),
         do: {:ok, {blknum, txindex, oindex}}
  end

  @spec parse_inputs(map()) :: [{integer(), integer(), integer()}] | {:error, any()}
  defp parse_inputs(message) do
    require Transaction.Payment

    0..(Transaction.Payment.max_inputs() - 1)
    |> Enum.map(fn i -> expect(message, "input#{i}", map: &parse_input/1) end)
    |> Enum.reject(&empty_input?/1)
    |> all_success_or_error()
  end

  @spec parse_output(map()) ::
          {:ok, {OMG.Crypto.address_t(), OMG.Crypto.address_t(), integer()}} | Base.validation_error_t()
  defp parse_output(output) do
    with {:ok, owner} <- expect(output, "owner", :address),
         {:ok, currency} <- expect(output, "currency", :address),
         {:ok, amount} <- expect(output, "amount", :non_neg_integer),
         do: {:ok, {owner, currency, amount}}
  end

  @spec parse_outputs(map()) :: [{OMG.Crypto.address_t(), OMG.Crypto.address_t(), integer()}] | {:error, any()}
  defp parse_outputs(message) do
    require Transaction.Payment

    0..(Transaction.Payment.max_outputs() - 1)
    |> Enum.map(fn i -> expect(message, "output#{i}", map: &parse_output/1) end)
    |> Enum.reject(&empty_output?/1)
    |> all_success_or_error()
  end

  # we do not longer pad with empty so we need to filter here, because typed data still require exact 4 in/outputs
  defp empty_input?({:ok, {0, 0, 0}}), do: true
  defp empty_input?(_input), do: false
  defp empty_output?({:ok, {_owner, _currency, 0}}), do: true
  defp empty_output?(_output), do: false
end
