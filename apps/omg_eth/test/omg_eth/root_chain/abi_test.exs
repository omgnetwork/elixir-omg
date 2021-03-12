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

defmodule OMG.Eth.RootChain.AbiTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias OMG.Eth.RootChain.Abi

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

    assert Abi.decode_log(deposit_created_log) == expected_event_parsed
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

    assert Abi.decode_log(input_piggybacked_log) == expected_event_parsed
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

    assert Abi.decode_log(output_piggybacked_log) == expected_event_parsed
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

    assert Abi.decode_log(block_submitted_log) == expected_event_parsed
  end

  test "if exit finalized event log can be decoded" do
    exit_finalized_log = %{
      :event_signature => "ExitFinalized(uint168)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0xcafbc4b710c5fab8f3d719f65053637407231ecde31a859f1709e3478a2eda54",
      "blockNumber" => "0x14a",
      "data" => "0x",
      "logIndex" => "0x2",
      "removed" => false,
      "topics" => [
        "0x70e52502e7b0d293b1482362622a6c356bb815e59c3f258858a7abb444193f0d",
        "0x000000000000000000000037a26a7116a84365892bb31bea5819301a2ba85b34"
      ],
      "transactionHash" => "0xbe310ade41278c5607620311b79363aa520ac46c7ba754bf3027d501c5a95f40",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(exit_finalized_log) == %{
             eth_height: 330,
             event_signature: "ExitFinalized(uint168)",
             exit_id: 81_309_820_288_462_349_357_922_495_476_773_313_169_175_330_970_420,
             log_index: 2,
             root_chain_txhash:
               <<190, 49, 10, 222, 65, 39, 140, 86, 7, 98, 3, 17, 183, 147, 99, 170, 82, 10, 196, 108, 123, 167, 84,
                 191, 48, 39, 213, 1, 197, 169, 95, 64>>
           }
  end

  test "if in flight exit challanged can be decoded" do
    in_flight_exit_challanged_log = %{
      :event_signature => "InFlightExitChallenged(address,bytes32,uint256,uint16,bytes,uint16,bytes)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0xcfffb9645dc8d73acc4c825b67ba62924c62402cc125564b655f469e0adeef32",
      "blockNumber" => "0x196",
      "data" =>
        "0x000000000000000000000000000000000000000000000000000000000000000b000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000003686579000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000036865790000000000000000000000000000000000000000000000000000000000",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0x8d80eb4f245f436d007299a3a1ba7abf25588af9cdcf918b697a8b6455272d58",
        "0x0000000000000000000000007ae8190d9968cbb3b52e56a56b2cd4cd5e15a44f",
        "0x7532528ec22439a9a1ed5f4fce6cd66d71625add6202cefb970c10d04f2d5091"
      ],
      "transactionHash" => "0xd9e3b3aaff8156dab8b004882d3bce834ba842c95deff7ec97da8f942f870ab4",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(in_flight_exit_challanged_log) == %{
             challenger: <<122, 232, 25, 13, 153, 104, 203, 179, 181, 46, 86, 165, 107, 44, 212, 205, 94, 21, 164, 79>>,
             competitor_position: 11,
             eth_height: 406,
             event_signature: "InFlightExitChallenged(address,bytes32,uint256,uint16,bytes,uint16,bytes)",
             log_index: 0,
             root_chain_txhash:
               <<217, 227, 179, 170, 255, 129, 86, 218, 184, 176, 4, 136, 45, 59, 206, 131, 75, 168, 66, 201, 93, 239,
                 247, 236, 151, 218, 143, 148, 47, 135, 10, 180>>,
             tx_hash:
               <<117, 50, 82, 142, 194, 36, 57, 169, 161, 237, 95, 79, 206, 108, 214, 109, 113, 98, 90, 221, 98, 2, 206,
                 251, 151, 12, 16, 208, 79, 45, 80, 145>>,
             challenge_tx: "hey",
             challenge_tx_input_index: 12,
             challenge_tx_sig: "hey",
             in_flight_tx_input_index: 10
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

    assert Abi.decode_log(exit_challenged_log) == %{
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

    assert Abi.decode_log(in_flight_exit_challenge_responded_log) == %{
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

    assert Abi.decode_log(in_flight_exit_output_blocked_log) == %{
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
      :event_signature => "InFlightExitStarted(address,bytes32,bytes,uint256[],bytes[],bytes[])",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0xc8d61620144825f38394feb2c9c1d721a161ed67c123c3cb1af787fb366866c1",
      "blockNumber" => "0x2d6",
      "data" =>
        "0x0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000000a5f8a301e1a0000000000000000000000000000000000000000000000000000000003b9aca00f85ced01eb9464727d219b68f2db584283583591883cd9cc342694000000000000000000000000000000000000000005ed01eb9464727d219b68f2db584283583591883cd9cc34269400000000000000000000000000000000000000000480a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000003b9aca00000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000041d64506ec32843fed58aa6731c38f3fa8b81256e900abbbcd56c8ad5168a44e452d2fd3f0cd4330b8d4fe935b8d1ad151eb8a75d6a3e65dac866450c211c746af1b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000055f85301c0eeed01eb9464727d219b68f2db584283583591883cd9cc34269400000000000000000000000000000000000000000a80a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0x9650546f63f8c929f52c753e240b0ee1e90d3af599016f3db6ff97066e0bd0f1",
        "0x00000000000000000000000064727d219b68f2db584283583591883cd9cc3426",
        "0x25f01fb32ff429c90a178a54dfbe5561ce67dafa2d5c65a1a8c3ccea2dd3531d"
      ],
      "transactionHash" => "0xf0e44af0d26443b9e5133c64f5a71f06a4d4d0d40c5e7412b5ea0dfcb2f1a133",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(in_flight_exit_started_log) == %{
             eth_height: 726,
             event_signature: "InFlightExitStarted(address,bytes32,bytes,uint256[],bytes[],bytes[])",
             initiator: "dr}!\x9Bh\xF2\xDBXB\x83X5\x91\x88<\xD9\xCC4&",
             log_index: 0,
             root_chain_txhash:
               <<240, 228, 74, 240, 210, 100, 67, 185, 229, 19, 60, 100, 245, 167, 31, 6, 164, 212, 208, 212, 12, 94,
                 116, 18, 181, 234, 13, 252, 178, 241, 161, 51>>,
             tx_hash: "%\xF0\x1F\xB3/\xF4)\xC9\n\x17\x8AT߾Ua\xCEg\xDA\xFA-\\e\xA1\xA8\xC3\xCC\xEA-\xD3S\x1D",
             in_flight_tx:
               "\xF8\xA3\x01\xE1\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0;\x9A\xCA\0\xF8\\\xED\x01\xEB\x94dr}!\x9Bh\xF2\xDBXB\x83X5\x91\x88<\xD9\xCC4&\x94\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x05\xED\x01\xEB\x94dr}!\x9Bh\xF2\xDBXB\x83X5\x91\x88<\xD9\xCC4&\x94\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x04\x80\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
             in_flight_tx_sigs: [
               "\xD6E\x06\xEC2\x84?\xEDX\xAAg1Ï?\xA8\xB8\x12V\xE9\0\xAB\xBB\xCDVȭQh\xA4NE-/\xD3\xF0\xCDC0\xB8\xD4\xFE\x93[\x8D\x1A\xD1Q\xEB\x8Au֣\xE6]\xAC\x86dP\xC2\x11\xC7F\xAF\e"
             ],
             input_utxos_pos: [1_000_000_000],
             input_txs: [
               "\xF8S\x01\xC0\xEE\xED\x01\xEB\x94dr}!\x9Bh\xF2\xDBXB\x83X5\x91\x88<\xD9\xCC4&\x94\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\n\x80\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
             ]
           }
  end

  test "if in flight exit output withdrawn can be decoded" do
    in_flight_exit_output_withdrawn_log = %{
      :event_signature => "InFlightExitOutputWithdrawn(uint168,uint16)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x2218cd9358fd6ed3b720b512b645a88a9a3ed9f472e6192fae202f60e40ac7a2",
      "blockNumber" => "0x14f",
      "data" => "0x0000000000000000000000000000000000000000000000000000000000000001",
      "logIndex" => "0x1",
      "removed" => false,
      "topics" => [
        "0x3dcc2251cfab3eb0f6c76eec13346767d46ed18e7277f4826d3ef0c033fe6959",
        "0x0000000000000000000000c61730bb3657b79c60055b84b2dfce5d269d555278"
      ],
      "transactionHash" => "0x50f80a28c7b45e5700d6e756a49d4c6ceebd5c4a5285b28abeb97058c941b966",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(in_flight_exit_output_withdrawn_log) == %{
             eth_height: 335,
             event_signature: "InFlightExitOutputWithdrawn(uint168,uint16)",
             in_flight_exit_id: 289_509_717_723_506_568_833_816_412_236_561_243_950_769_583_247_992,
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
      :event_signature => "ExitStarted(address,uint168,uint256,bytes)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x1bee6f75c74ceeb4817dc160e2fb56dd1337a9fc2980a2b013252cf1e620f246",
      "blockNumber" => "0x" <> Integer.to_string(726, 16),
      "data" =>
        "0x0000000000000000000000047b7c1bf35c82a6b6a91465ce5469fe235c6f5479000000000000000000000000000000000000000000000000000000e8d4a5100000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000076f87401e1a0000000000000000000000000000000000000000000000000000000003b9aca00eeed01eb943b9f4c1dd26e0be593373b1d36cee2008cbeb8379400000000000000000000000000000000000000000980a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      "logIndex" => "0x1",
      "removed" => false,
      "topics" => [
        "0xbe1fcee8d584647b0ce80e56f62c950e0cb2126418f52cc052a665e5f85a5d93",
        "0x0000000000000000000000003b9f4c1dd26e0be593373b1d36cee2008cbeb837"
      ],
      "transactionHash" => "0x4a8248b88a17b2be4c6086a1984622de1a60dda3c9dd9ece1ef97ed18efa028c",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(exit_started_log) == %{
             eth_height: 726,
             event_signature: "ExitStarted(address,uint168,uint256,bytes)",
             log_index: 1,
             root_chain_txhash:
               <<74, 130, 72, 184, 138, 23, 178, 190, 76, 96, 134, 161, 152, 70, 34, 222, 26, 96, 221, 163, 201, 221,
                 158, 206, 30, 249, 126, 209, 142, 250, 2, 140>>,
             exit_id: 6_550_980_141_382_864_406_435_341_734_958_993_618_605_523_817_593,
             owner: ";\x9FL\x1D\xD2n\v\xE5\x937;\x1D6\xCE\xE2\0\x8C\xBE\xB87",
             utxo_pos: 1_000_000_000_000,
             output_tx:
               "\xF8t\x01\xE1\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0;\x9A\xCA\0\xEE\xED\x01\xEB\x94;\x9FL\x1D\xD2n\v\xE5\x937;\x1D6\xCE\xE2\0\x8C\xBE\xB87\x94\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\t\x80\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
           }
  end

  test "blocks(uint256) function call gets decoded properly" do
    data =
      "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

    %{
      "block_hash" =>
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
      "block_timestamp" => 0
    } = Abi.decode_function(data, "blocks(uint256)")
  end

  test "nextChildBlock() function call gets decoded properly" do
    data =
      "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

    %{
      "block_number" => next_child_block
    } = Abi.decode_function(data, "nextChildBlock()")

    assert is_integer(next_child_block)
  end

  test "minExitPeriod() function call gets decoded properly" do
    data = "0x0000000000000000000000000000000000000000000000000000000000000014"

    %{"min_exit_period" => 20} = Abi.decode_function(data, "minExitPeriod()")
  end

  test "exitGames(uint256) function call gets decoded properly" do
    data =
      "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

    %{
      "block_hash" =>
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
      "block_timestamp" => 0
    } = Abi.decode_function(data, "blocks(uint256)")
  end

  test "vaults(uint256) function call gets decoded properly" do
    data = "0x0000000000000000000000004e3aeff70f022a6d4cc5947423887e7152826cf7"

    %{"vault_address" => vault_address} = Abi.decode_function(data, "vaults(uint256)")

    assert is_binary(vault_address)
  end

  test "getVersion() function call gets decoded properly" do
    data =
      "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000d312e302e342b6136396337363300000000000000000000000000000000000000"

    %{"version" => version} = Abi.decode_function(data, "getVersion()")

    assert is_binary(version)
  end

  test "childBlockInterval() function call gets decoded properly" do
    data = "0x00000000000000000000000000000000000000000000000000000000000003e8"

    %{"child_block_interval" => 1000} = Abi.decode_function(data, "childBlockInterval()")
  end
end
