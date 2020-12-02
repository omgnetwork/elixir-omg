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

defmodule OMG.SignatureTest do
  use ExUnit.Case, async: true
  doctest OMG.Signature
  alias OMG.Signature

  describe "recover_public/3" do
    test "returns an error from an invalid hash" do
      {:error, "invalid_recovery_id"} =
        Signature.recover_public(
          <<2::256>>,
          55,
          38_938_543_279_057_362_855_969_661_240_129_897_219_713_373_336_787_331_739_561_340_553_100_525_404_231,
          23_772_455_091_703_794_797_226_342_343_520_955_590_158_385_983_376_086_035_257_995_824_653_222_457_926
        )
    end

    test "recovers from generating a signed hash 1" do
      data =
        Base.decode16!("ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080",
          case: :lower
        )

      hash = elem(ExKeccak.hash_256(data), 1)
      v = 27
      r = 18_515_461_264_373_351_373_200_002_665_853_028_612_451_056_578_545_711_640_558_177_340_181_847_433_846
      s = 46_948_507_304_638_947_509_940_763_649_030_358_759_909_902_576_025_900_602_547_168_820_602_576_006_531
      {:ok, public_key} = Signature.recover_public(hash, v, r, s)

      assert public_key ==
               <<75, 194, 163, 18, 101, 21, 63, 7, 231, 14, 11, 171, 8, 114, 78, 107, 133, 226, 23, 248, 205, 98, 140,
                 235, 98, 151, 66, 71, 187, 73, 51, 130, 206, 40, 202, 183, 154, 215, 17, 158, 225, 173, 62, 188, 219,
                 152, 161, 104, 5, 33, 21, 48, 236, 198, 207, 239, 161, 184, 142, 109, 255, 153, 35, 42>>
    end

    test "recovers from generating a signed hash 2" do
      {v, r, s} =
        {37, 18_515_461_264_373_351_373_200_002_665_853_028_612_451_056_578_545_711_640_558_177_340_181_847_433_846,
         46_948_507_304_638_947_509_940_763_649_030_358_759_909_902_576_025_900_602_547_168_820_602_576_006_531}

      data =
        Base.decode16!("ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080",
          case: :lower
        )

      hash = elem(ExKeccak.hash_256(data), 1)
      {:ok, public_key} = Signature.recover_public(hash, v, r, s, 1)

      assert public_key ==
               <<75, 194, 163, 18, 101, 21, 63, 7, 231, 14, 11, 171, 8, 114, 78, 107, 133, 226, 23, 248, 205, 98, 140,
                 235, 98, 151, 66, 71, 187, 73, 51, 130, 206, 40, 202, 183, 154, 215, 17, 158, 225, 173, 62, 188, 219,
                 152, 161, 104, 5, 33, 21, 48, 236, 198, 207, 239, 161, 184, 142, 109, 255, 153, 35, 42>>
    end
  end
end
