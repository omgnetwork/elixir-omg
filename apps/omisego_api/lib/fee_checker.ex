defmodule OmiseGO.API.FeeChecker do
  @moduledoc """
  Maintains current fee rates and acceptable tokens, updates fees information from external source.
  Provides function to validate transaction's fee.
  """

  alias OmiseGO.API.FeeChecker.Core
  alias OmiseGO.API.State.Transaction.Recovered

  use GenServer
  use OmiseGO.API.LoggerExt

  @file_changed_check_interval_ms 10_000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(args) do
    :ok = ensure_ets_init()
    :ok = update_fee_spec()

    {:ok, _} = :timer.apply_interval(@file_changed_check_interval_ms, __MODULE__, :update_fee_spec, [])

    _ = Logger.info(fn -> "Started FeeChecker" end)
    {:ok, args}
  end

  @doc """
  Calculates fee from tx and checks whether token is allowed and flat fee limits are met
  """
  @spec transaction_fees(Recovered.t()) :: {:ok, Core.token_fee_t()} | {:error, :token_not_allowed}
  def transaction_fees(recovered_tx) do
    Core.transaction_fees(recovered_tx, load_fees())
  end

  @doc """
  Parses json encoded fee specifications file content and validates provided information
  """
  @spec parse_file_content(binary()) :: {:ok, list(Core.fee_spec_t())} | {:error, reason :: atom()}
  def parse_file_content(file_content) do
    file_content
    |> Core.parse_file_content()
    |> handle_parser_output()
  end

  @doc """
  Reads fee specification file if needed and updates :ets state with current fees information
  """
  @spec update_fee_spec() :: :ok | :file_unchanged | {:error, atom()}
  def update_fee_spec do
    path = Application.get_env(:omisego_api, :fee_specs_file_path)

    with {:reload, changed_at} <- should_load_file(path),
         {:ok, content} <- File.read(path),
         {:ok, specs} <- parse_file_content(content) do
      :ok = save_fees(specs, changed_at)
      _ = Logger.info(fn -> "Reloaded #{Enum.count(specs)} fee specs from file, changed at #{changed_at}" end)

      :ok
    else
      {:file_unchanged, last_change_at} ->
        _ = Logger.debug(fn -> "File unchanged, last modified at #{last_change_at}" end)
        :file_unchanged

      {:error, :enoent} ->
        _ =
          Logger.error(fn ->
            "The fee specification file #{path} not found in #{System.get_env("PWD")}"
          end)

        {:error, :fee_spec_not_found}

      error ->
        _ = Logger.warn(fn -> "Unable to update fees from file. Reason: #{inspect(error)}" end)
        error
    end
  end

  defp save_fees(fee_specs, loaded_at) do
    true = :ets.insert(:fees_bucket, {:last_loaded, loaded_at})
    true = :ets.insert(:fees_bucket, {:fees_map_key, fee_specs})
    :ok
  end

  defp load_fees do
    :ets.lookup_element(:fees_bucket, :fees_map_key, 2)
  end

  defp should_load_file(path) do
    loaded = get_last_loaded_file_timestamp()
    changed = get_file_last_modified_timestamp(path)

    if changed > loaded,
      do: {:reload, changed},
      else: {:file_unchanged, loaded}
  end

  defp get_last_loaded_file_timestamp do
    [{:last_loaded, timestamp}] = :ets.lookup(:fees_bucket, :last_loaded)
    # When not matched we prefer immediate crash here as this should never happened

    timestamp
  end

  defp get_file_last_modified_timestamp(path) do
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{mtime: mtime}} ->
        mtime

      # possibly wrong path - returns current timestamp to force file reload where file errors are handled
      _ ->
        :os.system_time(:second)
    end
  end

  defp ensure_ets_init do
    _ = if :undefined == :ets.info(:fees_bucket), do: :ets.new(:fees_bucket, [:set, :public, :named_table])

    true = :ets.insert(:fees_bucket, {:last_loaded, 0})
    :ok
  end

  defp handle_parser_output({[], fee_specs}) do
    _ = Logger.debug(fn -> "Parsing fee specification file completes successfully." end)
    {:ok, fee_specs}
  end

  defp handle_parser_output({[{error, _index} | _] = errors, _fee_specs}) do
    _ = Logger.warn(fn -> "Parsing fee specification file fails with errors:" end)

    Enum.each(errors, fn {{:error, reason}, index} ->
      _ = Logger.warn(fn -> " * ##{index} fee spec parser failed with error: #{inspect(reason)}" end)
    end)

    # return first error
    error
  end
end
