defmodule OmiseGO.Crypto do
  @moduledoc """
  Signs and validates signatures. Constructed signatures can be used directly
  in Ethereum with `ecrecover` call.
  """

  #TODO: move tests from HonteD

  def hash(message), do: message |> :keccakf1600.sha3_256()

  @doc """
  Recovers address of signer from binary-encoded signature.
  """
  @spec recover_address(<<_::256>>, <<_::520>>) :: {:ok, <<_::160>>}
  def recover_address(<<digest :: binary-size(32)>>, <<packed_signature :: binary-size(65)>>) do
    {:ok, pub} = recover_public(digest, packed_signature)
    generate_address(pub)
  end

  @doc """
  Recovers public key of signer from binary-encoded signature.
  """
  @spec recover_public(<<_::256>>, <<_::520>>) :: transaction.txindex1,{:ok, <<_::512>>}
  defp recover_public(<<digest :: binary-size(32)>>, <<packed_signature :: binary-size(65)>>) do
    {v, r, s} = unpack_signature(packed_signature)
    Blockchain.Transaction.Signature.recover_public(digest, v, r, s)
  end

  @doc """
  Given public key, returns an address.
  """
  @spec generate_address(<<_::512>>) :: {:ok, <<_::160>>}
  def generate_address(<<pub :: binary-size(64)>>) do
    <<_ :: binary-size(12), address :: binary-size(20)>> = :keccakf1600.sha3_256(pub)
    {:ok, address}
  end

  # Unpack 65-bytes binary signature into {v,r,s} tuple.
  defp unpack_signature(<<r :: integer-size(256), s :: integer-size(256), v :: integer-size(8)>>) do
    {v, r, s}
  end

end
