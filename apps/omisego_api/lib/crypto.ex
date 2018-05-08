defmodule OmiseGO.API.Crypto do
  @moduledoc """
  Signs and validates signatures. Constructed signatures can be used directly
  in Ethereum with `ecrecover` call.
  """

  @dialyzer {:nowarn_function, generate_public_key: 1}

  @doc """
  Produces a cryptographic digest of a message.
  """
  def hash(message), do: message |> :keccakf1600.sha3_256()

  @doc """
  Produce a stand-alone, 65 bytes long, signature for message of arbitrary length.
  """
  @spec signature(binary, <<_::256>>) :: <<_::520>>
  def signature(msg, priv) do
    msg
    |> hash()
    |> signature_digest(priv)
  end

  @doc """
  Produces a stand-alone, 65 bytes long, signature for message hash.
  """
  @spec signature_digest(<<_::256>>, <<_::256>>) :: <<_::520>>
  def signature_digest(digest, priv) when is_binary(digest) and byte_size(digest) == 32 do
    {v, r, s} = Blockchain.Transaction.Signature.sign_hash(digest, priv)
    pack_signature(v, r, s)
  end

  @doc """
  Verifies if private key corresponding to `address` was used to produce `signature` for
  this `msg` binary.
  """
  @spec verify(binary, binary, binary) :: {:ok, boolean}
  def verify(msg, signature, address) do
    {:ok, recovered_address} =
      msg |> hash() |> recover_address(signature)
    {:ok, address == recovered_address}
  end

  @doc """
  Recovers address of signer from binary-encoded signature.
  """
  @spec recover_address(<<_::256>>, <<_::520>>) :: {:ok, <<_::160>>} | {:error, :signature_corrupt}
  def recover_address(<<digest :: binary-size(32)>>, <<packed_signature :: binary-size(65)>>) do
    with {:ok, pub} <- recover_public(digest, packed_signature) do
      generate_address(pub)
    end
  end

  @doc """
  Recovers public key of signer from binary-encoded signature.
  """
  @spec recover_public(<<_::256>>, <<_::520>>) :: {:ok, <<_::512>>} | {:error, :signature_corrupt}
  def recover_public(<<digest :: binary-size(32)>>, <<packed_signature :: binary-size(65)>>) do
    {v, r, s} = unpack_signature(packed_signature)
    with {:ok, pub} = result <- Blockchain.Transaction.Signature.recover_public(digest, v, r, s) do
      result
    else
      {:error, "Recovery id invalid 0-3"} -> {:error, :signature_corrupt}
      other -> other
    end
  end

  @doc """
  Generates private key. Internally uses OpenSSL RAND_bytes. May throw if there is not enough entropy.
  TODO: Think about moving to something dependent on /dev/urandom instead. Might be less portable.
  """
  @spec generate_private_key() :: {:ok, <<_::256>>}
  def generate_private_key, do: {:ok, :crypto.strong_rand_bytes(32)}

  @doc """
  Given a private key, returns public key.
  """
  @spec generate_public_key(<<_::256>>) :: {:ok, <<_::512>>}
  def generate_public_key(<<priv :: binary-size(32)>>) do
    {:ok, der_pub} = Blockchain.Transaction.Signature.get_public_key(priv)
    {:ok, der_to_raw(der_pub)}
  end

  @doc """
  Given public key, returns an address.
  """
  @spec generate_address(<<_::512>>) :: {:ok, <<_::160>>}
  def generate_address(<<pub :: binary-size(64)>>) do
    <<_ :: binary-size(12), address :: binary-size(20)>> = :keccakf1600.sha3_256(pub)
    {:ok, address}
  end

  @spec address_to_hex(binary) :: binary()
  def address_to_hex(bin) when is_binary(bin) and byte_size(bin) == 20 do
    Base.encode16(bin, case: :lower)
  end

  @spec hex_to_address(binary) :: {:ok, binary()} | {:error, :bad_hex_encoding_of_address}
  def hex_to_address(hex) when is_binary(hex) and byte_size(hex) == 40 do
    case Base.decode16(hex, case: :lower) do
      {:ok, bin} -> {:ok, bin}
      :error -> {:error, :bad_hex_encoding_of_address}
    end
  end

  @spec hex_to_address!(binary) :: binary()
  def hex_to_address!(hex) do
    {:ok, address} = hex_to_address(hex)
    address
  end

  # private

  defp der_to_raw(<<4 :: integer-size(8), data :: binary>>), do: data

  # Pack a {v,r,s} signature as 65-bytes binary.
  defp pack_signature(v, r, s) do
    <<r :: integer-size(256), s :: integer-size(256), v :: integer-size(8)>>
  end

  # Unpack 65-bytes binary signature into {v,r,s} tuple.
  defp unpack_signature(<<r :: integer-size(256), s :: integer-size(256), v :: integer-size(8)>>) do
    {v, r, s}
  end

end
