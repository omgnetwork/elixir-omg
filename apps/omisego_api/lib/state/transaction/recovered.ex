defmodule OmiseGO.API.State.Transaction.Recovered do
  @moduledoc """
  Representation of a Signed transaction, with addresses recovered from signatures (from Transaction.Signed)
  Intent is to allow concurent processing of signatures outside of serial processing in state.ex
  """

  alias OmiseGO.API.Crypto
  alias OmiseGO.API.State.Transaction

  @empty_signature <<0::size(520)>>
  @type signed_tx_hash_t() :: <<_::768>>

  defstruct [:raw_tx, :signed_tx_hash, spender1: nil, spender2: nil, signed_tx_bytes: <<>>]

  @type t() :: %__MODULE__{
          raw_tx: Transaction.t(),
          signed_tx_hash: signed_tx_hash_t(),
          spender1: Crypto.address_t(),
          spender2: Crypto.address_t(),
          signed_tx_bytes: Transaction.Signed.signed_tx_bytes_t()
        }

  @spec recover_from(Transaction.Signed.t()) :: {:ok, t()} | any
  def recover_from(
        %Transaction.Signed{raw_tx: raw_tx, sig1: sig1, sig2: sig2, signed_tx_bytes: signed_tx_bytes} = signed_tx
      ) do
    hash_no_spenders = Transaction.hash(raw_tx)

    with {:ok, spender1} <- get_spender(hash_no_spenders, sig1),
         {:ok, spender2} <- get_spender(hash_no_spenders, sig2),
         do:
           {:ok,
            %__MODULE__{
              raw_tx: raw_tx,
              signed_tx_hash: Transaction.Signed.signed_hash(signed_tx),
              spender1: spender1,
              spender2: spender2,
              signed_tx_bytes: signed_tx_bytes
            }}
  end

  defp get_spender(_hash_no_spenders, @empty_signature), do: {:ok, nil}
  defp get_spender(hash_no_spenders, sig), do: Crypto.recover_address(hash_no_spenders, sig)
end
