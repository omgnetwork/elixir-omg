defmodule OmiseGO.API.CryptoTest do
  use ExUnit.Case, async: true

  @moduledoc """
  A sanity and compatibility check of the crypto implementation.
  """

  alias OmiseGO.API.Crypto

  test "sha3 library usage, address generation" do
    # test vectors below were generated using pyethereum's sha3 and privtoaddr
    priv = :keccakf1600.sha3_256(<<"11">>)
    py_priv = "7880aec93413f117ef14bd4e6d130875ab2c7d7d55a064fac3c2f7bd51516380"
    py_pub = "c4d178249d840f548b09ad8269e8a3165ce2c170"
    assert {:ok, ^priv} = Base.decode16(py_priv, case: :lower)
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)
    assert {:ok, ^address} = Base.decode16(py_pub, case: :lower)
  end

  test "signature compatibility" do
    msg = :keccakf1600.sha3_256("1234")
    priv = :keccakf1600.sha3_256("11")
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, _} = Crypto.generate_address(pub)
    # this test vector was generated using plasma.utils.utils.sign/2 from plasma-mvp
    py_signature =
      "b8670d619701733e1b4d10149bc90eb4eb276760d2f77a08a5428d4cbf2eadbd656f374c187b1ac80ce31d8c62076af26150e52ef1f33bfc07c6d244da7ca38c1c"

    sig = Crypto.signature_digest(msg, priv)
    assert ^sig = Base.decode16!(py_signature, case: :lower)
  end

  test "digest sign, recover" do
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)
    msg = :crypto.strong_rand_bytes(32)
    sig = Crypto.signature_digest(msg, priv)
    assert {:ok, ^address} = Crypto.recover_address(msg, sig)
  end

  test "sign, verify" do
    {:ok, priv} = Crypto.generate_private_key()
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    signature = Crypto.signature("message", priv)
    assert byte_size(signature) == 65
    assert {:ok, true} == Crypto.verify("message", signature, address)
    assert {:ok, false} == Crypto.verify("message2", signature, address)
  end
end
