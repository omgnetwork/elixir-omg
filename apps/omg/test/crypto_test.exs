# Copyright 2018 OmiseGO Pte Ltd
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

    signature = DevCrypto.signature("message", priv)
    assert byte_size(signature) == 65
    assert {:ok, true} == Crypto.verify("message", signature, address)
    assert {:ok, false} == Crypto.verify("message2", signature, address)
  end

  test "checking decode_address function for diffrent agruments" do
    assert {:error, :bad_address_encoding} = Crypto.decode_address("0x0123456789abCdeF")
    assert {:error, :bad_address_encoding} = Crypto.decode_address("this is not HEX")

    assert {:ok, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>} =
             Crypto.decode_address("0x0000000000000000000000000000000000000000")

    assert {:ok, <<65, 86, 211, 52, 45, 92, 56, 90, 135, 210, 100, 249, 6, 83, 115, 53, 146, 0, 5, 129>>} =
             Crypto.decode_address("0x4156d3342d5c385a87d264f90653733592000581")
  end

  test "checking encode_address function for diffrent agruments" do
    assert {:error, :invalid_address} = Crypto.encode_address(<<>>)
    assert {:error, :invalid_address} = Crypto.encode_address("this is not address")
    assert {:error, :invalid_address} = Crypto.encode_address(<<5, 86, 211, 52, 45, 92, 56, 90, 135>>)

    assert {:ok, "0x0000000000000000000000000000000000000000"} =
             Crypto.encode_address(<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>)

    assert {:ok, "0x4156d3342d5c385a87d264f90653733592000581"} =
             Crypto.encode_address(
               <<65, 86, 211, 52, 45, 92, 56, 90, 135, 210, 100, 249, 6, 83, 115, 53, 146, 0, 5, 129>>
             )
  end
end
