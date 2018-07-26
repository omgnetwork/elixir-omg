defmodule OmiseGO.API.Core do
  @moduledoc """
  Functional core work-horse for OmiseGO.API.
  """
  alias OmiseGO.API.State.Transaction

  @empty_signature <<0::size(520)>>

  @type recover_tx_error() ::
          :bad_signature_length
          | :duplicate_inputs
          | :input_missing_for_signature
          | :malformed_transaction
          | :malformed_transaction_rlp
          | :no_inputs
          | :signature_corrupt
          | :signature_missing_for_input

  @doc """
  Transforms an RLP-encoded child chain transaction (binary) into a:
    - decoded
    - statelessly valid (mainly inputs logic)
    - recovered (i.e. signatures get recovered into spenders)
  transaction
  """
  @spec recover_tx(binary) ::
          Transaction.Recovered.t()
          | {:error, recover_tx_error()}
  def recover_tx(encoded_signed_tx) do
    with {:ok, signed_tx} <- Transaction.Signed.decode(encoded_signed_tx),
         :ok <- valid?(signed_tx),
         do: Transaction.Recovered.recover_from(signed_tx)
  end

  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{
           blknum1: 0,
           txindex1: 0,
           oindex1: 0,
           blknum2: 0,
           txindex2: 0,
           oindex2: 0
         }
       }),
       do: {:error, :no_inputs}

  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{
           blknum1: blknum,
           txindex1: txindex,
           oindex1: oindex,
           blknum2: blknum,
           txindex2: txindex,
           oindex2: oindex
         }
       }),
       do: {:error, :duplicate_inputs}

  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{
           blknum1: 0,
           txindex1: 0,
           oindex1: 0
         },
         sig1: @empty_signature,
         sig2: @empty_signature
       }),
       do: {:error, :signature_missing_for_input}

  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{
           blknum2: 0,
           txindex2: 0,
           oindex2: 0
         },
         sig1: @empty_signature,
         sig2: @empty_signature
       }),
       do: {:error, :signature_missing_for_input}

  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{
           blknum1: 0,
           txindex1: 0,
           oindex1: 0
         },
         sig1: @empty_signature
       }),
       do: :ok

  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{
           blknum2: 0,
           txindex2: 0,
           oindex2: 0
         },
         sig2: @empty_signature
       }),
       do: :ok

  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{},
         sig2: @empty_signature
       }),
       do: {:error, :signature_missing_for_input}

  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{},
         sig1: @empty_signature
       }),
       do: {:error, :signature_missing_for_input}

  # NOTE input_missing_for_signature clauses are necessary, so that no superflous signature recovery takes place
  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{
           blknum1: 0,
           txindex1: 0,
           oindex1: 0
         }
       }),
       do: {:error, :input_missing_for_signature}

  defp valid?(%Transaction.Signed{
         raw_tx: %Transaction{
           blknum2: 0,
           txindex2: 0,
           oindex2: 0
         }
       }),
       do: {:error, :input_missing_for_signature}

  defp valid?(%Transaction.Signed{}), do: :ok
end
