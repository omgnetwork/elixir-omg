defmodule OmiseGO.API.FeeChecker do
  @moduledoc """
  Maintains current fee rates and acceptable tokens, updates fees information from external source.
  Provides function to validate transaction's fee.
  """

  alias OmiseGO.API.FeeChecker.Core
  alias OmiseGO.API.State.Transaction.Recovered
  alias Poison, as: Json

  require Logger

  use GenServer

  def init(args) do
    {:ok, args}
  end

  @doc """
  Calculates fee from tx and checks whether token is allowed and both percentage and flat fee limits are met
  """
  @spec transaction_fees(Recovered.t()) :: {:ok, Core.token_fee_t()} | {:error, :token_not_allowed}
  def transaction_fees(recovered_tx) do
    Core.transaction_fees(recovered_tx, [])
  end

  @doc """
  Parses json encoded fee specifications file content and validates provided information
  """
  @spec parse_file_content(list(map)) :: list(Core.fee_spec_t()) | {:error, reason :: atom()}
  def parse_file_content(file_content) do
    {:ok, json} = Json.decode(file_content)

    json
    |> Core.parse_fee_specs()
    |> handle_parser_output()
  end

  defp handle_parser_output({[], fee_specs}) do
    _ = Logger.info(fn -> "Parsing fee specification file completes successfully." end)
    fee_specs
  end

  defp handle_parser_output({[{error, _index} | _] = errors, _fee_specs}) do
    _ = Logger.warn(fn -> "Parsing fee specification file fails with errors:" end)

    _ =
      Enum.each(errors, fn {{:error, reason}, index} ->
        _ = Logger.warn(fn -> " * ##{index} fee spec parser failed with error: #{inspect(reason)}" end)
      end)

    # return first error
    error
  end
end
