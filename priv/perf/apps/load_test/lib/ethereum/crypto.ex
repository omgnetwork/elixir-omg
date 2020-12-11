defmodule LoadTest.Ethereum.Crypto do
  @moduledoc """
  Cryptography related utility functions
  """
  @type hash_t() :: <<_::256>>
  @type priv_key_t :: <<_::256>>

  @doc """
  Produces a KECCAK digest for the message.

  see https://hexdocs.pm/exth_crypto/ExthCrypto.Hash.html#kec/0
  """
  @spec hash(binary) :: hash_t()
  def hash(message), do: elem(ExKeccak.hash_256(message), 1)

  @doc """
  Generates private key. Internally uses OpenSSL RAND_bytes. May throw if there is not enough entropy.
  """
  @spec generate_private_key() :: {:ok, priv_key_t()}
  def generate_private_key, do: {:ok, :crypto.strong_rand_bytes(32)}
end
