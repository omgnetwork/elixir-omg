defmodule HonteD.Integration.Performance.Scenario do
  @moduledoc """
  Generating test scenarios for performance tests - mainly streams of transactions and other useful data
  """

  defstruct [:issuers, :create_token_txs, :tokens, :issue_txs, :holders_senders, :n_receivers, :failure_rate]

  import HonteD.Crypto
  import HonteD.Transaction

  @start_tokens 1_000_000
  @normal_amount 1

  defmodule Keys do
    @moduledoc """
    Convenience struct to handle blockchain identities
    """
    defstruct [:priv,
               :pub,
               :addr,
              ]
  end

  @doc """
  Define new scenario. Load transactions are generated lazily; scenario is deterministic and
  very synthetic.

  Each sender corresponds to one token and one issue transaction. Transactions for load phase
  of the test can be taken from streams in send_txs. Transaction validity is independent from
  global ordering of transactions.

  NOTE: failure rate is unsupported for now, but leaving the argument to demonstrate intention
  """
  def new(n_senders, n_receivers, failure_rate \\ 0.0)

  def new(n_senders, n_receivers, 0.0 = failure_rate)
  when
  0 <= failure_rate and
  failure_rate < 1 and
  n_senders > 0 and
  n_receivers > 0 do
    # Seed with hardcoded value instead of time-based value
    # This ensures determinism of the scenario generation process.
    _ = :rand.seed(:exs1024s, {123, 123_534, 345_345})
    issuers = Enum.map(1..n_senders, &generate_keys/1)
    {tokens, create_token_txs} = Enum.unzip(Enum.map(issuers, &create_token/1))
    holders_senders = Enum.map(1..n_senders, &generate_keys/1)
    issue_txs = Enum.map(:lists.zip3(issuers, tokens, holders_senders), &issue_token/1)
    %__MODULE__{issuers: issuers, create_token_txs: create_token_txs, tokens: tokens,
                holders_senders: holders_senders, issue_txs: issue_txs,
                n_receivers: n_receivers, failure_rate: failure_rate
    }
  end

  # NOTE need this, since thanks to Elixir's range support (1..0 == [0, 1]), we can't have it in the general clause
  def new(0, n_receivers, 0.0 = failure_rate) do
    %__MODULE__{issuers: [], create_token_txs: [], tokens: [],
                holders_senders: [], issue_txs: [],
                n_receivers: n_receivers, failure_rate: failure_rate
    }
  end

  def get_setup(model) do
    model.create_token_txs
    |> Enum.zip(model.issue_txs)
    |> Enum.map(&Tuple.to_list/1)
  end

  def get_senders(model) do
    model.holders_senders
  end

  def get_send_txs(model, [skip_per_stream: skip_per_stream]) do
    prepare_send_streams(model.holders_senders,
                         model.tokens,
                         model.n_receivers,
                         model.failure_rate,
                         skip_per_stream)
  end
  def get_send_txs(model), do: get_send_txs(model, skip_per_stream: 0)

  defp prepare_send_streams(holders_senders, tokens, n_receivers, _failure_rate, skip_per_stream) do
    args = Enum.zip(holders_senders, tokens)
    for {sender, token} <- args do
      transaction_generator = fn(nonce) ->
        receiver = current_receiver(nonce, n_receivers)
        {:ok, tx} = create_send([nonce: nonce, asset: token, amount: @normal_amount,
                                 from: sender.addr, to: receiver])

        # NOTE: the boolean here signals expected success/failure. For now always success (failure rate unsupported)
        {{true, signed_tx(tx, sender)}, nonce + 1}
      end

      # we're starting with nonce equal to the number of transactions to skip
      Stream.unfold(skip_per_stream, transaction_generator)
    end
  end

  defp current_receiver(number, n_receivers) do
    number
    |> Integer.mod(n_receivers)
    |> Integer.to_string
    |> String.pad_leading(37, "c")
    |> Kernel.<>("pub")
  end

  # All seeds are a function of initial_seed, but they do not overlap in practice
  def make_n_seeds(initial_seed, n) when n > 0 do
    1..n
    |> Enum.reduce([initial_seed], &seed_generator/2)
    |> Enum.take(n)
  end

  defp seed_generator(_, [last | _] = acc) do
    # Jump/1 is hard to use, so seed/1 -> jump/0 -> export_seed/0 instead.
    _ = :rand.seed(last)
    _ = :rand.jump()
    seed = :rand.export_seed()
    [seed | acc]
  end

  defp generate_keys(_) do
    {:ok, priv} = generate_private_key()
    {:ok, pub} = generate_public_key(priv)
    {:ok, addr} = generate_address(pub)
    %Keys{priv: priv, pub: pub, addr: addr}
  end

  defp create_token(issuer) do
    {:ok, tx} = create_create_token(nonce: 0, issuer: issuer.addr)
    tx = signed_tx(tx, issuer)
    token_addr = HonteD.Token.create_address(issuer.addr, 0)
    {token_addr, {true, tx}}
  end

  defp issue_token({issuer, token_addr, holder}) do
    {:ok, tx} = create_issue(nonce: 1, asset: token_addr, amount: @start_tokens,
      dest: holder.addr, issuer: issuer.addr)
    {true, signed_tx(tx, issuer)}
  end

  defp signed_tx(tx, acc) do
    tx
    |> HonteD.TxCodec.encode()
    |> Base.encode16()
    |> sign(acc.priv)
  end

end
