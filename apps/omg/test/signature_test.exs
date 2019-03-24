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

defmodule OMG.SignatureTest do
  use ExUnit.Case, async: true
  alias OMG.Signature

  test "get public key from private" do
    {:ok, public_key} = Signature.get_public_key(<<1::256>>)

    assert public_key ==
             <<4, 121, 190, 102, 126, 249, 220, 187, 172, 85, 160, 98, 149, 206, 135, 11, 7, 2, 155, 252, 219, 45, 206,
               40, 217, 89, 242, 129, 91, 22, 248, 23, 152, 72, 58, 218, 119, 38, 163, 196, 101, 93, 164, 251, 252, 14,
               17, 8, 168, 253, 23, 180, 72, 166, 133, 84, 25, 156, 71, 208, 143, 251, 16, 212, 184>>
  end

  test "that getting a public key from an invalid private key returns an error" do
    {:error, "Private key size not 32 bytes"} = Signature.get_public_key(<<1>>)
  end

  test "recovering a public key from correct signed hash" do
    {:ok, public_key} =
      Signature.recover_public(
        <<2::256>>,
        28,
        38_938_543_279_057_362_855_969_661_240_129_897_219_713_373_336_787_331_739_561_340_553_100_525_404_231,
        23_772_455_091_703_794_797_226_342_343_520_955_590_158_385_983_376_086_035_257_995_824_653_222_457_926
      )

    assert public_key ==
             <<121, 190, 102, 126, 249, 220, 187, 172, 85, 160, 98, 149, 206, 135, 11, 7, 2, 155, 252, 219, 45, 206, 40,
               217, 89, 242, 129, 91, 22, 248, 23, 152, 72, 58, 218, 119, 38, 163, 196, 101, 93, 164, 251, 252, 14, 17,
               8, 168, 253, 23, 180, 72, 166, 133, 84, 25, 156, 71, 208, 143, 251, 16, 212, 184>>
  end

  test "returning an error from an invalid hash" do
    {:error, "Recovery id invalid 0-3"} =
      Signature.recover_public(
        <<2::256>>,
        55,
        38_938_543_279_057_362_855_969_661_240_129_897_219_713_373_336_787_331_739_561_340_553_100_525_404_231,
        23_772_455_091_703_794_797_226_342_343_520_955_590_158_385_983_376_086_035_257_995_824_653_222_457_926
      )
  end

  test "recovering from generating a signed hash 1" do
    data =
      Base.decode16!("ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080",
        case: :lower
      )

    hash = :keccakf1600.sha3_256(data)
    v = 27
    r = 18_515_461_264_373_351_373_200_002_665_853_028_612_451_056_578_545_711_640_558_177_340_181_847_433_846
    s = 46_948_507_304_638_947_509_940_763_649_030_358_759_909_902_576_025_900_602_547_168_820_602_576_006_531
    {:ok, public_key} = Signature.recover_public(hash, v, r, s)

    assert public_key ==
             <<75, 194, 163, 18, 101, 21, 63, 7, 231, 14, 11, 171, 8, 114, 78, 107, 133, 226, 23, 248, 205, 98, 140,
               235, 98, 151, 66, 71, 187, 73, 51, 130, 206, 40, 202, 183, 154, 215, 17, 158, 225, 173, 62, 188, 219,
               152, 161, 104, 5, 33, 21, 48, 236, 198, 207, 239, 161, 184, 142, 109, 255, 153, 35, 42>>
  end

  test "recovering from generating a signed hash 2" do
    {v, r, s} =
      {37, 18_515_461_264_373_351_373_200_002_665_853_028_612_451_056_578_545_711_640_558_177_340_181_847_433_846,
       46_948_507_304_638_947_509_940_763_649_030_358_759_909_902_576_025_900_602_547_168_820_602_576_006_531}

    data =
      Base.decode16!("ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080",
        case: :lower
      )

    hash = :keccakf1600.sha3_256(data)
    {:ok, public_key} = Signature.recover_public(hash, v, r, s, 1)

    assert public_key ==
             <<75, 194, 163, 18, 101, 21, 63, 7, 231, 14, 11, 171, 8, 114, 78, 107, 133, 226, 23, 248, 205, 98, 140,
               235, 98, 151, 66, 71, 187, 73, 51, 130, 206, 40, 202, 183, 154, 215, 17, 158, 225, 173, 62, 188, 219,
               152, 161, 104, 5, 33, 21, 48, 236, 198, 207, 239, 161, 184, 142, 109, 255, 153, 35, 42>>
  end

  test "returning ecdsa signature for hash value 1" do
    {hash_v, hash_r, hash_s} = Signature.sign_hash(<<2::256>>, <<1::256>>)

    assert {hash_v, hash_r, hash_s} ==
             {28,
              38_938_543_279_057_362_855_969_661_240_129_897_219_713_373_336_787_331_739_561_340_553_100_525_404_231,
              23_772_455_091_703_794_797_226_342_343_520_955_590_158_385_983_376_086_035_257_995_824_653_222_457_926}
  end

  test "returning ecdsa signature for hash value 2" do
    {hash_v, hash_r, hash_s} = Signature.sign_hash(<<5::256>>, <<1::256>>)

    assert {hash_v, hash_r, hash_s} ==
             {27,
              74_927_840_775_756_275_467_012_999_236_208_995_857_356_645_681_540_064_312_847_180_029_125_478_834_483,
              56_037_731_387_691_402_801_139_111_075_060_162_264_934_372_456_622_294_904_359_821_823_785_637_523_849}
  end

  test "returning ecdsa signature for hash value 3" do
    data =
      Base.decode16!("ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080",
        case: :lower
      )

    hash = :keccakf1600.sha3_256(data)
    private_key = Base.decode16!("4646464646464646464646464646464646464646464646464646464646464646", case: :lower)
    {hash_v, hash_r, hash_s} = Signature.sign_hash(hash, private_key, 1)

    assert {hash_v, hash_r, hash_s} ==
             {37,
              18_515_461_264_373_351_373_200_002_665_853_028_612_451_056_578_545_711_640_558_177_340_181_847_433_846,
              46_948_507_304_638_947_509_940_763_649_030_358_759_909_902_576_025_900_602_547_168_820_602_576_006_531}
  end
end
