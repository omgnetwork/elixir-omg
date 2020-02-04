# Copyright 2019-2020 OmiseGO Pte Ltd
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

defmodule OMG.Eth.RootChain.DecodeTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias OMG.Eth.RootChain.Decode

  test "if deposit created event can be decoded from log" do
    deposit_created_log = %{
      :event_signature => "DepositCreated(address,uint256,address,uint256)",
      "address" => "0x4e3aeff70f022a6d4cc5947423887e7152826cf7",
      "blockHash" => "0xe5b0487de36b161f2d3e8c228ad4e1e84ab1ae25ca4d5ef53f9f03298ab3545f",
      "blockNumber" => "0x186",
      "data" => "0x000000000000000000000000000000000000000000000000000000000000000a",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0x18569122d84f30025bb8dffb33563f1bdbfb9637f21552b11b8305686e9cb307",
        "0x0000000000000000000000003b9f4c1dd26e0be593373b1d36cee2008cbeb837",
        "0x0000000000000000000000000000000000000000000000000000000000000001",
        "0x0000000000000000000000000000000000000000000000000000000000000000"
      ],
      "transactionHash" => "0x4d72a63ff42f1db50af2c36e8b314101d2fea3e0003575f30298e9153fe3d8ee",
      "transactionIndex" => "0x0"
    }

    expected_event_parsed = %{
      amount: 10,
      blknum: 1,
      currency: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
      eth_height: 390,
      event_signature: "DepositCreated(address,uint256,address,uint256)",
      log_index: 0,
      owner: <<59, 159, 76, 29, 210, 110, 11, 229, 147, 55, 59, 29, 54, 206, 226, 0, 140, 190, 184, 55>>,
      root_chain_txhash:
        <<77, 114, 166, 63, 244, 47, 29, 181, 10, 242, 195, 110, 139, 49, 65, 1, 210, 254, 163, 224, 0, 53, 117, 243, 2,
          152, 233, 21, 63, 227, 216, 238>>
    }

    assert Decode.deposit(deposit_created_log) == expected_event_parsed
  end

  test "if input piggybacked event log can be decoded" do
    input_piggybacked_log = %{
      :event_signature => "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x6d95b14290cc2ac112f1560f2cd7aa0d747b91ec9cb1d47e11c205270d83c88c",
      "blockNumber" => "0x19a",
      "data" => "0x0000000000000000000000000000000000000000000000000000000000000001",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0xa93c0e9b202feaf554acf6ef1185b898c9f214da16e51740b06b5f7487b018e5",
        "0x0000000000000000000000001513abcd3590a25e0bed840652d957391dde9955",
        "0xff90b77303e56bd230a9adf4a6553a95f5ffb563486205d6fba25d3e46594940"
      ],
      "transactionHash" => "0x0cc9e5556bbd6eeaf4302f44adca215786ff08cfa44a34be1760eca60f97364f",
      "transactionIndex" => "0x0"
    }

    expected_event_parsed = %{
      eth_height: 410,
      event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      log_index: 0,
      output_index: 1,
      owner: <<21, 19, 171, 205, 53, 144, 162, 94, 11, 237, 132, 6, 82, 217, 87, 57, 29, 222, 153, 85>>,
      root_chain_txhash:
        <<12, 201, 229, 85, 107, 189, 110, 234, 244, 48, 47, 68, 173, 202, 33, 87, 134, 255, 8, 207, 164, 74, 52, 190,
          23, 96, 236, 166, 15, 151, 54, 79>>,
      tx_hash:
        <<255, 144, 183, 115, 3, 229, 107, 210, 48, 169, 173, 244, 166, 85, 58, 149, 245, 255, 181, 99, 72, 98, 5, 214,
          251, 162, 93, 62, 70, 89, 73, 64>>,
      omg_data: %{piggyback_type: :input}
    }

    assert Decode.piggybacked(input_piggybacked_log) == expected_event_parsed
  end

  test "if output piggybacked event log can be decoded" do
    output_piggybacked_log = %{
      :event_signature => "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x3e34475a29dafb28cd6deb65bc1782ccf6d73d6673d462a6d404ac0993d1e7eb",
      "blockNumber" => "0x198",
      "data" => "0x0000000000000000000000000000000000000000000000000000000000000001",
      "logIndex" => "0x1",
      "removed" => false,
      "topics" => [
        "0x6ecd8e79a5f67f6c12b54371ada2ffb41bc128c61d9ac1e969f0aa2aca46cd78",
        "0x0000000000000000000000001513abcd3590a25e0bed840652d957391dde9955",
        "0xff90b77303e56bd230a9adf4a6553a95f5ffb563486205d6fba25d3e46594940"
      ],
      "transactionHash" => "0x7cf43a6080e99677dee0b26c23e469b1df9cfb56a5c3f2a0123df6edae7b5b5e",
      "transactionIndex" => "0x0"
    }

    expected_event_parsed = %{
      eth_height: 408,
      event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      log_index: 1,
      output_index: 1,
      owner: <<21, 19, 171, 205, 53, 144, 162, 94, 11, 237, 132, 6, 82, 217, 87, 57, 29, 222, 153, 85>>,
      root_chain_txhash:
        <<124, 244, 58, 96, 128, 233, 150, 119, 222, 224, 178, 108, 35, 228, 105, 177, 223, 156, 251, 86, 165, 195, 242,
          160, 18, 61, 246, 237, 174, 123, 91, 94>>,
      tx_hash:
        <<255, 144, 183, 115, 3, 229, 107, 210, 48, 169, 173, 244, 166, 85, 58, 149, 245, 255, 181, 99, 72, 98, 5, 214,
          251, 162, 93, 62, 70, 89, 73, 64>>,
      omg_data: %{piggyback_type: :output}
    }

    assert Decode.piggybacked(output_piggybacked_log) == expected_event_parsed
  end

  test "if block emitted event log can be decoded" do
    block_submitted_log = %{
      :event_signature => "BlockSubmitted(uint256)",
      "address" => "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
      "blockHash" => "0x31285f2f55e9334ae24a2bab8d5211b6f85177820f5ddf42cba652e0a88488c1",
      "blockNumber" => "0x18e",
      "data" => "0x00000000000000000000000000000000000000000000000000000000000003e8",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => ["0x5a978f4723b249ccf79cd7a658a8601ce1ff8b89fc770251a6be35216351ce32"],
      "transactionHash" => "0x297559979b5efa854ad29e216c76a64c3f43621bbf3dc16e4b31fb0cb6dcebf4",
      "transactionIndex" => "0x0"
    }

    expected_event_parsed = %{
      blknum: 1000,
      eth_height: 398,
      event_signature: "BlockSubmitted(uint256)",
      log_index: 0,
      root_chain_txhash:
        <<41, 117, 89, 151, 155, 94, 250, 133, 74, 210, 158, 33, 108, 118, 166, 76, 63, 67, 98, 27, 191, 61, 193, 110,
          75, 49, 251, 12, 182, 220, 235, 244>>
    }

    assert Decode.block_submitted(block_submitted_log) == expected_event_parsed
  end

  test "if exit finalized event log can be decoded" do
    exit_finalized_log = %{
      :event_signature => "ExitFinalized(uint160)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0xcafbc4b710c5fab8f3d719f65053637407231ecde31a859f1709e3478a2eda54",
      "blockNumber" => "0x14a",
      "data" => "0x",
      "logIndex" => "0x2",
      "removed" => false,
      "topics" => [
        "0x0adb29b0831e081044cefe31155c1f2b2b85ad3613a480a5f901ee287addef55",
        "0x000000000000000000000000003fd275046f2823936fd97c1e3c8b225464d7f1"
      ],
      "transactionHash" => "0xbe310ade41278c5607620311b79363aa520ac46c7ba754bf3027d501c5a95f40",
      "transactionIndex" => "0x0"
    }

    assert Decode.exit_finalized(exit_finalized_log) == %{
             eth_height: 330,
             event_signature: "ExitFinalized(uint160)",
             exit_id: 1_423_280_346_484_099_708_949_144_162_169_101_241_792_387_057,
             log_index: 2,
             root_chain_txhash:
               <<190, 49, 10, 222, 65, 39, 140, 86, 7, 98, 3, 17, 183, 147, 99, 170, 82, 10, 196, 108, 123, 167, 84,
                 191, 48, 39, 213, 1, 197, 169, 95, 64>>
           }
  end

  test "if in flight exit challanged can be decoded" do
    in_flight_exit_challanged_log = %{
      :event_signature => "InFlightExitChallenged(address,bytes32,uint256)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0xcfffb9645dc8d73acc4c825b67ba62924c62402cc125564b655f469e0adeef32",
      "blockNumber" => "0x196",
      "data" => "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0x687401968e501bda2d2d6f880dd1a0a56ff50b1787185ee0b6f4c3fb9fc417ab",
        "0x0000000000000000000000007ae8190d9968cbb3b52e56a56b2cd4cd5e15a44f",
        "0x7532528ec22439a9a1ed5f4fce6cd66d71625add6202cefb970c10d04f2d5091"
      ],
      "transactionHash" => "0xd9e3b3aaff8156dab8b004882d3bce834ba842c95deff7ec97da8f942f870ab4",
      "transactionIndex" => "0x0"
    }

    assert Decode.in_flight_exit_challenged(in_flight_exit_challanged_log) == %{
             challenger: <<122, 232, 25, 13, 153, 104, 203, 179, 181, 46, 86, 165, 107, 44, 212, 205, 94, 21, 164, 79>>,
             competitor_position:
               115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935,
             eth_height: 406,
             event_signature: "InFlightExitChallenged(address,bytes32,uint256)",
             log_index: 0,
             root_chain_txhash:
               <<217, 227, 179, 170, 255, 129, 86, 218, 184, 176, 4, 136, 45, 59, 206, 131, 75, 168, 66, 201, 93, 239,
                 247, 236, 151, 218, 143, 148, 47, 135, 10, 180>>,
             tx_hash:
               <<117, 50, 82, 142, 194, 36, 57, 169, 161, 237, 95, 79, 206, 108, 214, 109, 113, 98, 90, 221, 98, 2, 206,
                 251, 151, 12, 16, 208, 79, 45, 80, 145>>
           }
  end

  test "if exit challenged can be decoded " do
    exit_challenged_log = %{
      :event_signature => "ExitChallenged(uint256)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x95948e75cb18f299ba10e528401a9a2debf19e26425190582f7e01d888cbb7d0",
      "blockNumber" => "0x11f",
      "data" => "0x",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0x5dfba526c59b25f899f935c5b0d5b8739e97e4d89c38c158eca3192ea34b87d8",
        "0x000000000000000000000000000000000000000000000000000000e8d4a51000"
      ],
      "transactionHash" => "0x4252551c98e590863df08fd6389c616aab511038306ab8f78224a82d15070325",
      "transactionIndex" => "0x0"
    }

    assert Decode.exit_challenged(exit_challenged_log) == %{
             eth_height: 287,
             event_signature: "ExitChallenged(uint256)",
             log_index: 0,
             root_chain_txhash:
               <<66, 82, 85, 28, 152, 229, 144, 134, 61, 240, 143, 214, 56, 156, 97, 106, 171, 81, 16, 56, 48, 106, 184,
                 247, 130, 36, 168, 45, 21, 7, 3, 37>>,
             utxo_pos: 1_000_000_000_000
           }
  end

  test "if in flight exit challenge responded can be decoded" do
    in_flight_exit_challenge_responded_log = %{
      :event_signature => "InFlightExitChallengeResponded(address,bytes32,uint256)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x4f3960b70634b34d69fa4a05c5d3561809cb66f2890539a01187f040a44988d1",
      "blockNumber" => "0x125",
      "data" => "0x000000000000000000000000000000000000000000000000000000e8d4a51000",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0x637cc4a7148767df19331a5c7dfb6d31f0a7e159a3dbb28a716be18c8c74f768",
        "0x00000000000000000000000018e688329ff9d6197108a66619912cda5d9ea163",
        "0xe60f426cbc3714ba7235df24027bf296d4d52a1a0cb36d46d6c88a3940f98d6b"
      ],
      "transactionHash" => "0x3fb63662a52fdc05d471fed92b65c9c53a9b0d990b7baefce318a6e4fa6cd517",
      "transactionIndex" => "0x0"
    }

    assert Decode.in_flight_exit_challenge_responded(in_flight_exit_challenge_responded_log) == %{
             challenge_position: 1_000_000_000_000,
             challenger: <<24, 230, 136, 50, 159, 249, 214, 25, 113, 8, 166, 102, 25, 145, 44, 218, 93, 158, 161, 99>>,
             eth_height: 293,
             event_signature: "InFlightExitChallengeResponded(address,bytes32,uint256)",
             log_index: 0,
             root_chain_txhash:
               <<63, 182, 54, 98, 165, 47, 220, 5, 212, 113, 254, 217, 43, 101, 201, 197, 58, 155, 13, 153, 11, 123,
                 174, 252, 227, 24, 166, 228, 250, 108, 213, 23>>,
             tx_hash:
               <<230, 15, 66, 108, 188, 55, 20, 186, 114, 53, 223, 36, 2, 123, 242, 150, 212, 213, 42, 26, 12, 179, 109,
                 70, 214, 200, 138, 57, 64, 249, 141, 107>>
           }
  end

  test "if challenge in flight exit not cannonical can be decoded" do
    eth_tx_input =
      <<232, 54, 34, 152, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 32, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 32, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 64, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 85, 248, 83, 1, 192, 238, 237, 1,
        235, 148, 140, 7, 214, 39, 36, 232, 102, 145, 82, 184, 199, 23, 67, 29, 135, 188, 216, 208, 23, 89, 148, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 165, 248, 163, 1, 225, 160, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0, 248, 92, 237, 1, 235, 148,
        140, 7, 214, 39, 36, 232, 102, 145, 82, 184, 199, 23, 67, 29, 135, 188, 216, 208, 23, 89, 148, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 237, 1, 235, 148, 140, 7, 214, 39, 36, 232, 102, 145, 82, 184, 199,
        23, 67, 29, 135, 188, 216, 208, 23, 89, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 128,
        160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 118, 248, 116, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 59, 154, 202, 0, 238, 237, 1, 235, 148, 130, 28, 224, 68,
        235, 159, 239, 63, 140, 241, 0, 192, 44, 230, 131, 216, 224, 52, 2, 224, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 65, 213, 14, 110, 137, 144, 125, 5, 4, 94, 64, 55, 85, 66, 96, 210, 166, 41, 110, 42, 187,
        199, 54, 83, 228, 31, 85, 4, 44, 153, 33, 56, 182, 104, 35, 67, 129, 11, 98, 78, 229, 81, 4, 199, 65, 155, 47,
        3, 187, 179, 69, 65, 239, 135, 219, 72, 233, 93, 232, 14, 157, 74, 187, 190, 63, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

    assert Decode.challenge_in_flight_exit_not_canonical(eth_tx_input) ==
             %{
               competing_tx:
                 <<248, 116, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                   0, 0, 59, 154, 202, 0, 238, 237, 1, 235, 148, 130, 28, 224, 68, 235, 159, 239, 63, 140, 241, 0, 192,
                   44, 230, 131, 216, 224, 52, 2, 224, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                   9, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                   0, 0, 0>>,
               competing_tx_input_index: 0,
               competing_tx_pos: 0,
               competing_tx_sig:
                 <<213, 14, 110, 137, 144, 125, 5, 4, 94, 64, 55, 85, 66, 96, 210, 166, 41, 110, 42, 187, 199, 54, 83,
                   228, 31, 85, 4, 44, 153, 33, 56, 182, 104, 35, 67, 129, 11, 98, 78, 229, 81, 4, 199, 65, 155, 47, 3,
                   187, 179, 69, 65, 239, 135, 219, 72, 233, 93, 232, 14, 157, 74, 187, 190, 63, 28>>,
               in_flight_input_index: 0,
               in_flight_tx:
                 <<248, 163, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                   0, 0, 59, 154, 202, 0, 248, 92, 237, 1, 235, 148, 140, 7, 214, 39, 36, 232, 102, 145, 82, 184, 199,
                   23, 67, 29, 135, 188, 216, 208, 23, 89, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                   0, 5, 237, 1, 235, 148, 140, 7, 214, 39, 36, 232, 102, 145, 82, 184, 199, 23, 67, 29, 135, 188, 216,
                   208, 23, 89, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 128, 160, 0, 0, 0,
                   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
               input_tx_bytes:
                 <<248, 83, 1, 192, 238, 237, 1, 235, 148, 140, 7, 214, 39, 36, 232, 102, 145, 82, 184, 199, 23, 67, 29,
                   135, 188, 216, 208, 23, 89, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 128,
                   160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                   0>>,
               input_utxo_pos: 1_000_000_000
             }
  end

  test "if in flight exit input/output blocked can be decoded " do
    in_flight_exit_output_blocked_log = %{
      :event_signature => "InFlightExitOutputBlocked(address,bytes32,uint16)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x1be26da1ab54eaf962157ae6c2079179a3024eeaa993d4f326e659e99cf8215e",
      "blockNumber" => "0x1b6",
      "data" => "0x0000000000000000000000000000000000000000000000000000000000000001",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0xcbe8dad2e7fcbfe0dcba2f9b2e44f122c66cd26dc0808a0f7e9ec41e4fe285bf",
        "0x000000000000000000000000d5089cfa403a6031a1f383bd467e980ed0bd5cba",
        "0x2a3f2ef50884e123a32a2c40d86758e8fe5b82a9a2b82e2c0849be6f13c95702"
      ],
      "transactionHash" => "0x984796ba697b532be624029990fc6d4f72e4e1434cf68dcf3b05b34b7987c468",
      "transactionIndex" => "0x0"
    }

    assert Decode.in_flight_exit_blocked(in_flight_exit_output_blocked_log) == %{
             challenger: <<213, 8, 156, 250, 64, 58, 96, 49, 161, 243, 131, 189, 70, 126, 152, 14, 208, 189, 92, 186>>,
             eth_height: 438,
             event_signature: "InFlightExitOutputBlocked(address,bytes32,uint16)",
             log_index: 0,
             output_index: 1,
             root_chain_txhash:
               <<152, 71, 150, 186, 105, 123, 83, 43, 230, 36, 2, 153, 144, 252, 109, 79, 114, 228, 225, 67, 76, 246,
                 141, 207, 59, 5, 179, 75, 121, 135, 196, 104>>,
             tx_hash:
               <<42, 63, 46, 245, 8, 132, 225, 35, 163, 42, 44, 64, 216, 103, 88, 232, 254, 91, 130, 169, 162, 184, 46,
                 44, 8, 73, 190, 111, 19, 201, 87, 2>>,
             omg_data: %{piggyback_type: :output}
           }
  end

  test "if in flight exit started can be decoded" do
    in_flight_exit_started_log = %{
      :event_signature => "InFlightExitStarted(address,bytes32)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0xc8d61620144825f38394feb2c9c1d721a161ed67c123c3cb1af787fb366866c1",
      "blockNumber" => "0x2d6",
      "data" => "0x",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0xd5f1fe9d48880b57daa227004b16d320c0eb885d6c49d472d54c16a05fa3179e",
        "0x0000000000000000000000002c6a9f42318025cd6627baf21c468201622020df",
        "0x4f46053b5df585094cc652ddd8c365962a3889c2053592f18331b95a7dff620e"
      ],
      "transactionHash" => "0xf0e44af0d26443b9e5133c64f5a71f06a4d4d0d40c5e7412b5ea0dfcb2f1a133",
      "transactionIndex" => "0x0"
    }

    assert Decode.in_flight_exit_started(in_flight_exit_started_log) == %{
             eth_height: 726,
             event_signature: "InFlightExitStarted(address,bytes32)",
             initiator: <<44, 106, 159, 66, 49, 128, 37, 205, 102, 39, 186, 242, 28, 70, 130, 1, 98, 32, 32, 223>>,
             log_index: 0,
             root_chain_txhash:
               <<240, 228, 74, 240, 210, 100, 67, 185, 229, 19, 60, 100, 245, 167, 31, 6, 164, 212, 208, 212, 12, 94,
                 116, 18, 181, 234, 13, 252, 178, 241, 161, 51>>,
             tx_hash:
               <<79, 70, 5, 59, 93, 245, 133, 9, 76, 198, 82, 221, 216, 195, 101, 150, 42, 56, 137, 194, 5, 53, 146,
                 241, 131, 49, 185, 90, 125, 255, 98, 14>>
           }
  end

  test "if start in flight exit can be decoded " do
    in_flight_exit_start_log =
      <<90, 82, 133, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 160, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 64, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 126, 248, 124, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 210, 32, 127, 180, 0, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18,
        141, 145, 248, 79, 186, 190, 47, 160, 172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136,
        69, 99, 145, 130, 68, 244, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 93, 248, 91, 1,
        192, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18, 141, 145, 248, 79, 186, 190, 47, 160,
        172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 138, 199, 35, 4, 137, 232, 0, 0, 128,
        160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 210, 32, 127, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 243, 154, 134, 159, 98, 231, 92, 245, 240, 191, 145, 70, 136, 166, 178,
        137, 202, 242, 4, 148, 53, 216, 230, 140, 92, 94, 109, 5, 228, 73, 19, 243, 78, 213, 192, 45, 109, 72, 200, 147,
        36, 134, 201, 157, 58, 217, 153, 229, 216, 148, 157, 195, 190, 59, 48, 88, 204, 41, 121, 105, 12, 62, 58, 98,
        28, 121, 43, 20, 191, 102, 248, 42, 243, 111, 0, 245, 251, 167, 1, 79, 160, 193, 226, 255, 60, 124, 39, 59, 254,
        82, 60, 26, 207, 103, 220, 63, 95, 160, 128, 166, 134, 165, 160, 208, 92, 61, 72, 34, 253, 84, 214, 50, 220,
        156, 192, 75, 22, 22, 4, 110, 186, 44, 228, 153, 235, 154, 247, 159, 94, 185, 73, 105, 10, 4, 4, 171, 244, 206,
        186, 252, 124, 255, 250, 56, 33, 145, 183, 221, 158, 125, 247, 120, 88, 30, 111, 183, 142, 250, 179, 95, 211,
        100, 201, 213, 218, 218, 212, 86, 155, 109, 212, 127, 127, 234, 186, 250, 53, 113, 248, 66, 67, 68, 37, 84, 131,
        53, 172, 110, 105, 13, 208, 113, 104, 216, 188, 91, 119, 151, 156, 26, 103, 2, 51, 79, 82, 159, 87, 131, 247,
        158, 148, 47, 210, 205, 3, 246, 229, 90, 194, 207, 73, 110, 132, 159, 222, 156, 68, 111, 171, 70, 168, 210, 125,
        177, 227, 16, 15, 39, 90, 119, 125, 56, 91, 68, 227, 203, 192, 69, 202, 186, 201, 218, 54, 202, 224, 64, 173,
        81, 96, 130, 50, 76, 150, 18, 124, 242, 159, 69, 53, 235, 91, 126, 186, 207, 226, 161, 214, 211, 170, 184, 236,
        4, 131, 211, 32, 121, 168, 89, 255, 112, 249, 33, 89, 112, 168, 190, 235, 177, 193, 100, 196, 116, 232, 36, 56,
        23, 76, 142, 235, 111, 188, 140, 180, 89, 75, 136, 201, 68, 143, 29, 64, 176, 155, 234, 236, 172, 91, 69, 219,
        110, 65, 67, 74, 18, 43, 105, 92, 90, 133, 134, 45, 142, 174, 64, 179, 38, 143, 111, 55, 228, 20, 51, 123, 227,
        142, 186, 122, 181, 187, 243, 3, 208, 31, 75, 122, 224, 127, 215, 62, 220, 47, 59, 224, 94, 67, 148, 138, 52,
        65, 138, 50, 114, 80, 156, 67, 194, 129, 26, 130, 30, 92, 152, 43, 165, 24, 116, 172, 125, 201, 221, 121, 168,
        12, 194, 240, 95, 111, 102, 76, 157, 187, 46, 69, 68, 53, 19, 125, 160, 108, 228, 77, 228, 85, 50, 165, 106, 58,
        112, 7, 162, 208, 198, 180, 53, 247, 38, 249, 81, 4, 191, 166, 231, 7, 4, 111, 193, 84, 186, 233, 24, 152, 208,
        58, 26, 10, 198, 249, 180, 94, 71, 22, 70, 226, 85, 90, 199, 158, 63, 232, 126, 177, 120, 30, 38, 242, 5, 0, 36,
        12, 55, 146, 116, 254, 145, 9, 110, 96, 209, 84, 90, 128, 69, 87, 31, 218, 185, 181, 48, 208, 214, 231, 232,
        116, 110, 120, 191, 159, 32, 244, 232, 111, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 65,
        52, 191, 197, 222, 130, 0, 246, 100, 25, 133, 115, 123, 250, 19, 77, 122, 226, 50, 133, 34, 71, 195, 27, 188,
        147, 104, 200, 235, 121, 231, 64, 251, 107, 58, 88, 55, 118, 117, 53, 9, 224, 81, 93, 0, 167, 62, 195, 202, 233,
        207, 237, 254, 185, 95, 207, 246, 144, 69, 242, 160, 58, 161, 96, 70, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

    assert Decode.start_in_flight_exit(in_flight_exit_start_log) == %{
             in_flight_tx:
               <<248, 124, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
                 210, 32, 127, 180, 0, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18, 141, 145,
                 248, 79, 186, 190, 47, 160, 172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136,
                 69, 99, 145, 130, 68, 244, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
             in_flight_tx_sigs: [
               <<52, 191, 197, 222, 130, 0, 246, 100, 25, 133, 115, 123, 250, 19, 77, 122, 226, 50, 133, 34, 71, 195,
                 27, 188, 147, 104, 200, 235, 121, 231, 64, 251, 107, 58, 88, 55, 118, 117, 53, 9, 224, 81, 93, 0, 167,
                 62, 195, 202, 233, 207, 237, 254, 185, 95, 207, 246, 144, 69, 242, 160, 58, 161, 96, 70, 28>>
             ],
             input_inclusion_proofs: [
               <<243, 154, 134, 159, 98, 231, 92, 245, 240, 191, 145, 70, 136, 166, 178, 137, 202, 242, 4, 148, 53, 216,
                 230, 140, 92, 94, 109, 5, 228, 73, 19, 243, 78, 213, 192, 45, 109, 72, 200, 147, 36, 134, 201, 157, 58,
                 217, 153, 229, 216, 148, 157, 195, 190, 59, 48, 88, 204, 41, 121, 105, 12, 62, 58, 98, 28, 121, 43, 20,
                 191, 102, 248, 42, 243, 111, 0, 245, 251, 167, 1, 79, 160, 193, 226, 255, 60, 124, 39, 59, 254, 82, 60,
                 26, 207, 103, 220, 63, 95, 160, 128, 166, 134, 165, 160, 208, 92, 61, 72, 34, 253, 84, 214, 50, 220,
                 156, 192, 75, 22, 22, 4, 110, 186, 44, 228, 153, 235, 154, 247, 159, 94, 185, 73, 105, 10, 4, 4, 171,
                 244, 206, 186, 252, 124, 255, 250, 56, 33, 145, 183, 221, 158, 125, 247, 120, 88, 30, 111, 183, 142,
                 250, 179, 95, 211, 100, 201, 213, 218, 218, 212, 86, 155, 109, 212, 127, 127, 234, 186, 250, 53, 113,
                 248, 66, 67, 68, 37, 84, 131, 53, 172, 110, 105, 13, 208, 113, 104, 216, 188, 91, 119, 151, 156, 26,
                 103, 2, 51, 79, 82, 159, 87, 131, 247, 158, 148, 47, 210, 205, 3, 246, 229, 90, 194, 207, 73, 110, 132,
                 159, 222, 156, 68, 111, 171, 70, 168, 210, 125, 177, 227, 16, 15, 39, 90, 119, 125, 56, 91, 68, 227,
                 203, 192, 69, 202, 186, 201, 218, 54, 202, 224, 64, 173, 81, 96, 130, 50, 76, 150, 18, 124, 242, 159,
                 69, 53, 235, 91, 126, 186, 207, 226, 161, 214, 211, 170, 184, 236, 4, 131, 211, 32, 121, 168, 89, 255,
                 112, 249, 33, 89, 112, 168, 190, 235, 177, 193, 100, 196, 116, 232, 36, 56, 23, 76, 142, 235, 111, 188,
                 140, 180, 89, 75, 136, 201, 68, 143, 29, 64, 176, 155, 234, 236, 172, 91, 69, 219, 110, 65, 67, 74, 18,
                 43, 105, 92, 90, 133, 134, 45, 142, 174, 64, 179, 38, 143, 111, 55, 228, 20, 51, 123, 227, 142, 186,
                 122, 181, 187, 243, 3, 208, 31, 75, 122, 224, 127, 215, 62, 220, 47, 59, 224, 94, 67, 148, 138, 52, 65,
                 138, 50, 114, 80, 156, 67, 194, 129, 26, 130, 30, 92, 152, 43, 165, 24, 116, 172, 125, 201, 221, 121,
                 168, 12, 194, 240, 95, 111, 102, 76, 157, 187, 46, 69, 68, 53, 19, 125, 160, 108, 228, 77, 228, 85, 50,
                 165, 106, 58, 112, 7, 162, 208, 198, 180, 53, 247, 38, 249, 81, 4, 191, 166, 231, 7, 4, 111, 193, 84,
                 186, 233, 24, 152, 208, 58, 26, 10, 198, 249, 180, 94, 71, 22, 70, 226, 85, 90, 199, 158, 63, 232, 126,
                 177, 120, 30, 38, 242, 5, 0, 36, 12, 55, 146, 116, 254, 145, 9, 110, 96, 209, 84, 90, 128, 69, 87, 31,
                 218, 185, 181, 48, 208, 214, 231, 232, 116, 110, 120, 191, 159, 32, 244, 232, 111, 6>>
             ],
             input_txs: [
               <<248, 91, 1, 192, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18, 141, 145, 248,
                 79, 186, 190, 47, 160, 172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 138,
                 199, 35, 4, 137, 232, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
             ],
             input_utxos_pos: [2_002_000_000_000]
           }
  end

  test "if in flight exit finalized can be decoded" do
    in_flight_exit_finalized_log = %{
      :event_signature => "InFlightExitOutputWithdrawn(uint160,uint16)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x2218cd9358fd6ed3b720b512b645a88a9a3ed9f472e6192fae202f60e40ac7a2",
      "blockNumber" => "0x14f",
      "data" => "0x0000000000000000000000000000000000000000000000000000000000000001",
      "logIndex" => "0x1",
      "removed" => false,
      "topics" => [
        "0xa241c6deaf193e53a1b002d779e4f247bf5d57ba0be5a753e628dfcee645a4f7",
        "0x00000000000000000000000000acccc8410b2139de37be92bb345c4fa10644a4"
      ],
      "transactionHash" => "0x50f80a28c7b45e5700d6e756a49d4c6ceebd5c4a5285b28abeb97058c941b966",
      "transactionIndex" => "0x0"
    }

    assert Decode.in_flight_exit_finalized(in_flight_exit_finalized_log) == %{
             eth_height: 335,
             event_signature: "InFlightExitOutputWithdrawn(uint160,uint16)",
             in_flight_exit_id: 3_853_567_223_408_339_354_111_409_210_931_346_801_537_991_844,
             log_index: 1,
             output_index: 1,
             root_chain_txhash:
               <<80, 248, 10, 40, 199, 180, 94, 87, 0, 214, 231, 86, 164, 157, 76, 108, 238, 189, 92, 74, 82, 133, 178,
                 138, 190, 185, 112, 88, 201, 65, 185, 102>>,
             omg_data: %{piggyback_type: :output}
           }
  end

  test "if exit started can be decoded" do
    exit_started_log = %{
      :event_signature => "ExitStarted(address,uint160)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x1bee6f75c74ceeb4817dc160e2fb56dd1337a9fc2980a2b013252cf1e620f246",
      "blockNumber" => "0x2f7",
      "data" => "0x000000000000000000000000002b191e750d8d4d3dcad14a9c8e5a5cf0c81761",
      "logIndex" => "0x1",
      "removed" => false,
      "topics" => [
        "0xdd6f755cba05d0a420007aef6afc05e4889ab424505e2e440ecd1c434ba7082e",
        "0x00000000000000000000000008858124b3b880c68b360fd319cc61da27545e9a"
      ],
      "transactionHash" => "0x4a8248b88a17b2be4c6086a1984622de1a60dda3c9dd9ece1ef97ed18efa028c",
      "transactionIndex" => "0x0"
    }

    assert Decode.exit_started(exit_started_log) == %{
             eth_height: 759,
             event_signature: "ExitStarted(address,uint160)",
             exit_id: 961_120_214_746_159_734_848_620_722_848_998_552_444_082_017,
             log_index: 1,
             owner: <<8, 133, 129, 36, 179, 184, 128, 198, 139, 54, 15, 211, 25, 204, 97, 218, 39, 84, 94, 154>>,
             root_chain_txhash:
               <<74, 130, 72, 184, 138, 23, 178, 190, 76, 96, 134, 161, 152, 70, 34, 222, 26, 96, 221, 163, 201, 221,
                 158, 206, 30, 249, 126, 209, 142, 250, 2, 140>>
           }
  end

  test "if start standard exit can be decoded" do
    start_standard_exit_log =
      <<112, 224, 20, 98, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 209, 228, 228, 234, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 96, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 224, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 93, 248, 91, 1, 192, 246, 245, 1, 243, 148, 8, 133,
        129, 36, 179, 184, 128, 198, 139, 54, 15, 211, 25, 204, 97, 218, 39, 84, 94, 154, 148, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 13, 224, 182, 179, 167, 100, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 243, 154, 134, 159, 98, 231, 92, 245, 240, 191,
        145, 70, 136, 166, 178, 137, 202, 242, 4, 148, 53, 216, 230, 140, 92, 94, 109, 5, 228, 73, 19, 243, 78, 213,
        192, 45, 109, 72, 200, 147, 36, 134, 201, 157, 58, 217, 153, 229, 216, 148, 157, 195, 190, 59, 48, 88, 204, 41,
        121, 105, 12, 62, 58, 98, 28, 121, 43, 20, 191, 102, 248, 42, 243, 111, 0, 245, 251, 167, 1, 79, 160, 193, 226,
        255, 60, 124, 39, 59, 254, 82, 60, 26, 207, 103, 220, 63, 95, 160, 128, 166, 134, 165, 160, 208, 92, 61, 72, 34,
        253, 84, 214, 50, 220, 156, 192, 75, 22, 22, 4, 110, 186, 44, 228, 153, 235, 154, 247, 159, 94, 185, 73, 105,
        10, 4, 4, 171, 244, 206, 186, 252, 124, 255, 250, 56, 33, 145, 183, 221, 158, 125, 247, 120, 88, 30, 111, 183,
        142, 250, 179, 95, 211, 100, 201, 213, 218, 218, 212, 86, 155, 109, 212, 127, 127, 234, 186, 250, 53, 113, 248,
        66, 67, 68, 37, 84, 131, 53, 172, 110, 105, 13, 208, 113, 104, 216, 188, 91, 119, 151, 156, 26, 103, 2, 51, 79,
        82, 159, 87, 131, 247, 158, 148, 47, 210, 205, 3, 246, 229, 90, 194, 207, 73, 110, 132, 159, 222, 156, 68, 111,
        171, 70, 168, 210, 125, 177, 227, 16, 15, 39, 90, 119, 125, 56, 91, 68, 227, 203, 192, 69, 202, 186, 201, 218,
        54, 202, 224, 64, 173, 81, 96, 130, 50, 76, 150, 18, 124, 242, 159, 69, 53, 235, 91, 126, 186, 207, 226, 161,
        214, 211, 170, 184, 236, 4, 131, 211, 32, 121, 168, 89, 255, 112, 249, 33, 89, 112, 168, 190, 235, 177, 193,
        100, 196, 116, 232, 36, 56, 23, 76, 142, 235, 111, 188, 140, 180, 89, 75, 136, 201, 68, 143, 29, 64, 176, 155,
        234, 236, 172, 91, 69, 219, 110, 65, 67, 74, 18, 43, 105, 92, 90, 133, 134, 45, 142, 174, 64, 179, 38, 143, 111,
        55, 228, 20, 51, 123, 227, 142, 186, 122, 181, 187, 243, 3, 208, 31, 75, 122, 224, 127, 215, 62, 220, 47, 59,
        224, 94, 67, 148, 138, 52, 65, 138, 50, 114, 80, 156, 67, 194, 129, 26, 130, 30, 92, 152, 43, 165, 24, 116, 172,
        125, 201, 221, 121, 168, 12, 194, 240, 95, 111, 102, 76, 157, 187, 46, 69, 68, 53, 19, 125, 160, 108, 228, 77,
        228, 85, 50, 165, 106, 58, 112, 7, 162, 208, 198, 180, 53, 247, 38, 249, 81, 4, 191, 166, 231, 7, 4, 111, 193,
        84, 186, 233, 24, 152, 208, 58, 26, 10, 198, 249, 180, 94, 71, 22, 70, 226, 85, 90, 199, 158, 63, 232, 126, 177,
        120, 30, 38, 242, 5, 0, 36, 12, 55, 146, 116, 254, 145, 9, 110, 96, 209, 84, 90, 128, 69, 87, 31, 218, 185, 181,
        48, 208, 214, 231, 232, 116, 110, 120, 191, 159, 32, 244, 232, 111, 6>>

    assert Decode.start_standard_exit(start_standard_exit_log) == %{
             output_tx:
               <<248, 91, 1, 192, 246, 245, 1, 243, 148, 8, 133, 129, 36, 179, 184, 128, 198, 139, 54, 15, 211, 25, 204,
                 97, 218, 39, 84, 94, 154, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 13,
                 224, 182, 179, 167, 100, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
             utxo_pos: 2_001_000_000_000
           }
  end
end
