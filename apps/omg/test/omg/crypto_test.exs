# Copyright 2019 OmiseGO Pte Ltd
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

defmodule OMG.CryptoTest do
  use ExUnit.Case, async: true

  @moduledoc """
  A sanity and compatibility check of the crypto implementation.
  """

  alias OMG.Crypto
  alias OMG.DevCrypto
  alias OMG.State.Transaction
  alias OMG.TypedDataHash

  test "sha3 library usage, address generation" do
    # test vectors below were generated using pyethereum's sha3 and privtoaddr
    priv = Crypto.hash(<<"11">>)
    py_priv = "7880aec93413f117ef14bd4e6d130875ab2c7d7d55a064fac3c2f7bd51516380"
    py_pub = "c4d178249d840f548b09ad8269e8a3165ce2c170"
    assert {:ok, ^priv} = Base.decode16(py_priv, case: :lower)
    {:ok, pub} = DevCrypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)
    assert {:ok, ^address} = Base.decode16(py_pub, case: :lower)
  end

  test "signature compatibility" do
    msg = Crypto.hash("1234")
    priv = Crypto.hash("11")
    {:ok, pub} = DevCrypto.generate_public_key(priv)
    {:ok, _} = Crypto.generate_address(pub)
    # this test vector was generated using plasma.utils.utils.sign/2 from plasma-mvp
    py_signature =
      "b8670d619701733e1b4d10149bc90eb4eb276760d2f77a08a5428d4cbf2eadbd656f374c187b1ac80ce31d8c62076af26150e52ef1f33bfc07c6d244da7ca38c1c"

    sig = DevCrypto.signature_digest(msg, priv)
    assert ^sig = Base.decode16!(py_signature, case: :lower)
  end

  test "digest sign, recover" do
    {:ok, priv} = DevCrypto.generate_private_key()
    {:ok, pub} = DevCrypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)
    msg = :crypto.strong_rand_bytes(32)
    sig = DevCrypto.signature_digest(msg, priv)
    assert {:ok, ^address} = Crypto.recover_address(msg, sig)
  end

  test "sign, verify" do
    {:ok, priv} = DevCrypto.generate_private_key()
    {:ok, pub} = DevCrypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    raw_tx = Transaction.Payment.new([{1000, 1, 0}], [])
    signature = DevCrypto.signature(raw_tx, priv)
    assert byte_size(signature) == 65

    assert true ==
             raw_tx
             |> TypedDataHash.hash_struct()
             |> Crypto.recover_address(signature)
             |> (&match?({:ok, ^address}, &1)).()

    assert false ==
             Transaction.Payment.new([{1000, 0, 1}], [])
             |> TypedDataHash.hash_struct()
             |> Crypto.recover_address(signature)
             |> (&match?({:ok, ^address}, &1)).()
  end
end
