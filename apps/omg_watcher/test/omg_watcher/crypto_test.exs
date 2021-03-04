# Copyright 2019-2020 OMG Network Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.CryptoTest do
  use ExUnit.Case, async: true
  doctest OMG.Watcher.Crypto

  @moduledoc """
  A sanity and compatibility check of the crypto implementation.
  """

  alias OMG.Watcher.Crypto
  alias OMG.Watcher.DevCrypto
  alias OMG.Watcher.State.Transaction
  alias OMG.Watcher.TypedDataHash

  describe "recover_address/2" do
    # Tests that we can digest, sign, and recover.
    test "recovers address of the signer from a binary-encoded signature" do
      {:ok, priv} = DevCrypto.generate_private_key()
      {:ok, pub} = DevCrypto.generate_public_key(priv)
      {:ok, address} = Crypto.generate_address(pub)

      msg = :crypto.strong_rand_bytes(32)
      sig = DevCrypto.signature_digest(msg, priv)

      assert {:ok, ^address} = Crypto.recover_address(msg, sig)
    end

    # Test that we can sign and verify
    test "recovers address from an encoded transaction" do
      {:ok, priv} = DevCrypto.generate_private_key()
      {:ok, pub} = DevCrypto.generate_public_key(priv)
      {:ok, address} = Crypto.generate_address(pub)

      raw_tx = Transaction.Payment.new([{1000, 1, 0}], [])
      signature = DevCrypto.signature(raw_tx, priv)
      assert byte_size(signature) == 65

      assert raw_tx
             |> TypedDataHash.hash_struct()
             |> Crypto.recover_address(signature)
             |> (&match?({:ok, ^address}, &1)).()

      refute Transaction.Payment.new([{1000, 0, 1}], [])
             |> TypedDataHash.hash_struct()
             |> Crypto.recover_address(signature)
             |> (&match?({:ok, ^address}, &1)).()
    end
  end

  describe "generate_address/1" do
    test "generates an address with SHA3" do
      # test vectors below were generated using pyethereum's sha3 and privtoaddr
      py_priv = "7880aec93413f117ef14bd4e6d130875ab2c7d7d55a064fac3c2f7bd51516380"
      py_pub = "c4d178249d840f548b09ad8269e8a3165ce2c170"
      priv = Crypto.hash(<<"11">>)

      {:ok, pub} = DevCrypto.generate_public_key(priv)
      {:ok, address} = Crypto.generate_address(pub)
      {:ok, decoded_private} = Base.decode16(py_priv, case: :lower)
      {:ok, decoded_address} = Base.decode16(py_pub, case: :lower)

      assert ^decoded_private = priv
      assert ^address = decoded_address
    end

    test "generates an address with a public signature" do
      # test vector was generated using plasma.utils.utils.sign/2 from plasma-mvp
      py_signature =
        "b8670d619701733e1b4d10149bc90eb4eb276760d2f77a08a5428d4cbf2eadbd656f374c187b1ac80ce31d8c62076af26150e52ef1f33bfc07c6d244da7ca38c1c"

      msg = Crypto.hash("1234")
      priv = Crypto.hash("11")

      {:ok, pub} = DevCrypto.generate_public_key(priv)
      {:ok, _} = Crypto.generate_address(pub)

      sig = DevCrypto.signature_digest(msg, priv)
      assert ^sig = Base.decode16!(py_signature, case: :lower)
    end
  end
end
