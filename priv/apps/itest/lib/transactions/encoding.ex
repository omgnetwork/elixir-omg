defmodule Itest.Transactions.Encoding do
  @moduledoc """
    Provides helper functions for encoding and decoding data.
  """
  @output_type_marker <<1>>

  alias Itest.Transactions.Deposit

  def get_data_for_rlp(%Deposit{inputs: inputs, outputs: outputs, metadata: metadata}),
    do: [@output_type_marker, inputs, outputs, metadata]

  def to_binary(hex) do
    hex
    |> String.replace_prefix("0x", "")
    |> String.upcase()
    |> Base.decode16!()
  end

  def to_hex(binary) when is_binary(binary),
    do: "0x" <> Base.encode16(binary, case: :lower)

  def to_hex(integer) when is_integer(integer),
    do: "0x" <> Integer.to_string(integer, 16)

  @doc """
  Produces a stand-alone, 65 bytes long, signature for message hash.
  """
  @spec signature_digest(<<_::256>>, <<_::256>>) :: <<_::520>>
  def signature_digest(hash_digest, private_key_hash) do
    private_key_binary = to_binary(private_key_hash)

    {:ok, <<r::size(256), s::size(256)>>, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(
        hash_digest,
        private_key_binary,
        :default,
        <<>>
      )

    # EIP-155
    # See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
    base_recovery_id = 27
    recovery_id = base_recovery_id + recovery_id

    <<r::integer-size(256), s::integer-size(256), recovery_id::integer-size(8)>>
  end
end
