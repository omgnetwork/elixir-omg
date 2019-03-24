defmodule OMG.Signature do
  @moduledoc """
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.

  For any of the following functions, if chain_id is specified,
  it's assumed that we're post-fork and we should follow the
  specification EIP-155 from:

  https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
  """

  @type public_key :: <<_::512>>
  @type private_key :: <<_::256>>
  @type hash_v :: integer()
  @type hash_r :: integer()
  @type hash_s :: integer()
  @base_recovery_id 27
  @base_recovery_id_eip_155 35

  @doc """
  Given a private key, returns a public key.

  This covers Eq.(206) of the Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.Signature.get_public_key(<<1::256>>)
      {:ok, <<4, 121, 190, 102, 126, 249, 220, 187, 172, 85, 160, 98, 149,
              206, 135, 11, 7, 2, 155, 252, 219, 45, 206, 40, 217, 89,
              242, 129, 91, 22, 248, 23, 152, 72, 58, 218, 119, 38, 163,
              196, 101, 93, 164, 251, 252, 14, 17, 8, 168, 253, 23, 180,
              72, 166, 133, 84, 25, 156, 71, 208, 143, 251, 16, 212, 184>>}

      iex> Blockchain.Transaction.Signature.get_public_key(<<1>>)
      {:error, "Private key size not 32 bytes"}
  """
  @spec get_public_key(private_key) :: {:ok, public_key} | {:error, String.t()}
  def get_public_key(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  @doc """
  Recovers a public key from a signed hash.

  This implements Eq.(208) of the Yellow Paper, adapted from https://stackoverflow.com/a/20000007

  ## Examples

    iex> Blockchain.Transaction.Signature.recover_public(<<2::256>>, 28, 38938543279057362855969661240129897219713373336787331739561340553100525404231, 23772455091703794797226342343520955590158385983376086035257995824653222457926)
    {:ok, <<121, 190, 102, 126, 249, 220, 187, 172, 85, 160, 98, 149, 206, 135, 11, 7, 2,
            155, 252, 219, 45, 206, 40, 217, 89, 242, 129, 91, 22, 248, 23, 152, 72, 58,
            218, 119, 38, 163, 196, 101, 93, 164, 251, 252, 14, 17, 8, 168, 253, 23, 180,
            72, 166, 133, 84, 25, 156, 71, 208, 143, 251, 16, 212, 184>>}

    iex> Blockchain.Transaction.Signature.recover_public(<<2::256>>, 55, 38938543279057362855969661240129897219713373336787331739561340553100525404231, 23772455091703794797226342343520955590158385983376086035257995824653222457926)
    {:error, "Recovery id invalid 0-3"}

    iex> data = "ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080" |> BitHelper.from_hex
    iex> hash = data |> BitHelper.kec
    iex> v = 27
    iex> r = 18515461264373351373200002665853028612451056578545711640558177340181847433846
    iex> s = 46948507304638947509940763649030358759909902576025900602547168820602576006531
    iex> Blockchain.Transaction.Signature.recover_public(hash, v, r, s)
    {:ok,
      <<75, 194, 163, 18, 101, 21, 63, 7, 231, 14, 11, 171, 8, 114, 78, 107, 133,
        226, 23, 248, 205, 98, 140, 235, 98, 151, 66, 71, 187, 73, 51, 130, 206, 40,
        202, 183, 154, 215, 17, 158, 225, 173, 62, 188, 219, 152, 161, 104, 5, 33,
        21, 48, 236, 198, 207, 239, 161, 184, 142, 109, 255, 153, 35, 42>>}

    iex> { v, r, s } = { 37, 18515461264373351373200002665853028612451056578545711640558177340181847433846, 46948507304638947509940763649030358759909902576025900602547168820602576006531 }
    iex> data = "ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080" |> BitHelper.from_hex
    iex> hash = data |> BitHelper.kec
    iex> Blockchain.Transaction.Signature.recover_public(hash, v, r, s, 1)
    {:ok, <<75, 194, 163, 18, 101, 21, 63, 7, 231, 14, 11, 171, 8, 114, 78, 107, 133,
            226, 23, 248, 205, 98, 140, 235, 98, 151, 66, 71, 187, 73, 51, 130, 206, 40,
            202, 183, 154, 215, 17, 158, 225, 173, 62, 188, 219, 152, 161, 104, 5, 33,
            21, 48, 236, 198, 207, 239, 161, 184, 142, 109, 255, 153, 35, 42>>}
  """
  @spec recover_public(BitHelper.keccak_hash(), hash_v, hash_r, hash_s, integer() | nil) ::
          {:ok, public_key} | {:error, String.t()}
  def recover_public(hash, v, r, s, chain_id \\ nil) do
    signature =
      pad(:binary.encode_unsigned(r), 32) <>
        pad(:binary.encode_unsigned(s), 32)

    # Fork Ψ EIP-155
    recovery_id =
      if not is_nil(chain_id) and uses_chain_id?(v) do
        v - chain_id * 2 - @base_recovery_id_eip_155
      else
        v - @base_recovery_id
      end

    case :libsecp256k1.ecdsa_recover_compact(hash, signature, :uncompressed, recovery_id) do
      {:ok, <<_byte::8, public_key::binary()>>} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  @doc """
  Returns a ECDSA signature (v,r,s) for a given hashed value.

  This implementes Eq.(207) of the Yellow Paper.

  ## Examples

    iex> Blockchain.Transaction.Signature.sign_hash(<<2::256>>, <<1::256>>)
    {28,
     38938543279057362855969661240129897219713373336787331739561340553100525404231,
     23772455091703794797226342343520955590158385983376086035257995824653222457926}

    iex> Blockchain.Transaction.Signature.sign_hash(<<5::256>>, <<1::256>>)
    {27,
     74927840775756275467012999236208995857356645681540064312847180029125478834483,
     56037731387691402801139111075060162264934372456622294904359821823785637523849}

    iex> data = "ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080" |> BitHelper.from_hex
    iex> hash = data |> BitHelper.kec
    iex> private_key = "4646464646464646464646464646464646464646464646464646464646464646" |> BitHelper.from_hex
    iex> Blockchain.Transaction.Signature.sign_hash(hash, private_key, 1)
    { 37, 18515461264373351373200002665853028612451056578545711640558177340181847433846, 46948507304638947509940763649030358759909902576025900602547168820602576006531 }
  """
  @spec sign_hash(BitHelper.keccak_hash(), private_key, integer() | nil) ::
          {hash_v, hash_r, hash_s}
  def sign_hash(hash, private_key, chain_id \\ nil) do
    {:ok, <<r::size(256), s::size(256)>>, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(hash, private_key, :default, <<>>)

    # Fork Ψ EIP-155
    recovery_id =
      if chain_id do
        chain_id * 2 + @base_recovery_id_eip_155 + recovery_id
      else
        @base_recovery_id + recovery_id
      end

    {recovery_id, r, s}
  end

  @spec uses_chain_id?(hash_v) :: boolean()
  defp uses_chain_id?(v) do
    v >= @base_recovery_id_eip_155
  end

  @spec pad(binary(), integer()) :: binary()
  defp pad(binary, desired_length) do
    desired_bits = desired_length * 8

    case byte_size(binary) do
      0 ->
        <<0::size(desired_bits)>>

      x when x <= desired_length ->
        padding_bits = (desired_length - x) * 8
        <<0::size(padding_bits)>> <> binary

      _ ->
        raise "Binary too long for padding"
    end
  end
end
