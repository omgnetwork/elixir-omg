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

defmodule OMG.Watcher.DatadogEvent.EncodeTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias OMG.Watcher.DatadogEvent.Encode

  test "if deposit created event can be decoded from log" do
    deposit_created_event = %{
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

    assert Encode.make_it_readable!(deposit_created_event) == %{
             amount: 10,
             blknum: 1,
             currency: "0x0000000000000000000000000000000000000000",
             eth_height: 390,
             event_signature: "DepositCreated(address,uint256,address,uint256)",
             log_index: 0,
             owner: "0x3b9f4c1dd26e0be593373b1d36cee2008cbeb837",
             root_chain_txhash: "0x4d72a63ff42f1db50af2c36e8b314101d2fea3e0003575f30298e9153fe3d8ee"
           }
  end

  test "if input piggybacked event log can be decoded" do
    input_piggybacked_event = %{
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

    assert Encode.make_it_readable!(input_piggybacked_event) == %{
             output_index: 1,
             owner: "0x1513abcd3590a25e0bed840652d957391dde9955",
             tx_hash: "0xff90b77303e56bd230a9adf4a6553a95f5ffb563486205d6fba25d3e46594940",
             eth_height: 410,
             event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)",
             log_index: 0,
             omg_data: %{piggyback_type: :input},
             root_chain_txhash: "0x0cc9e5556bbd6eeaf4302f44adca215786ff08cfa44a34be1760eca60f97364f"
           }
  end

  test "if output piggybacked event log can be decoded" do
    output_piggybacked_event = %{
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

    assert Encode.make_it_readable!(output_piggybacked_event) == %{
             log_index: 1,
             omg_data: %{piggyback_type: :output},
             output_index: 1,
             eth_height: 408,
             event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
             root_chain_txhash: "0x7cf43a6080e99677dee0b26c23e469b1df9cfb56a5c3f2a0123df6edae7b5b5e",
             owner: "0x1513abcd3590a25e0bed840652d957391dde9955",
             tx_hash: "0xff90b77303e56bd230a9adf4a6553a95f5ffb563486205d6fba25d3e46594940"
           }
  end

  test "if block emitted event log can be decoded" do
    block_submitted_event = %{
      blknum: 1000,
      eth_height: 398,
      event_signature: "BlockSubmitted(uint256)",
      log_index: 0,
      root_chain_txhash:
        <<41, 117, 89, 151, 155, 94, 250, 133, 74, 210, 158, 33, 108, 118, 166, 76, 63, 67, 98, 27, 191, 61, 193, 110,
          75, 49, 251, 12, 182, 220, 235, 244>>
    }

    assert Encode.make_it_readable!(block_submitted_event) == %{
             blknum: 1000,
             eth_height: 398,
             event_signature: "BlockSubmitted(uint256)",
             log_index: 0,
             root_chain_txhash: "0x297559979b5efa854ad29e216c76a64c3f43621bbf3dc16e4b31fb0cb6dcebf4"
           }
  end

  test "if exit finalized event log can be decoded" do
    exit_finalized_event = %{
      eth_height: 330,
      event_signature: "ExitFinalized(uint168)",
      exit_id: 81_309_820_288_462_349_357_922_495_476_773_313_169_175_330_970_420,
      log_index: 2,
      root_chain_txhash:
        <<190, 49, 10, 222, 65, 39, 140, 86, 7, 98, 3, 17, 183, 147, 99, 170, 82, 10, 196, 108, 123, 167, 84, 191, 48,
          39, 213, 1, 197, 169, 95, 64>>
    }

    assert Encode.make_it_readable!(exit_finalized_event) == %{
             eth_height: 330,
             event_signature: "ExitFinalized(uint168)",
             exit_id: 81_309_820_288_462_349_357_922_495_476_773_313_169_175_330_970_420,
             log_index: 2,
             root_chain_txhash: "0xbe310ade41278c5607620311b79363aa520ac46c7ba754bf3027d501c5a95f40"
           }
  end

  test "if in flight exit challanged can be decoded" do
    in_flight_exit_challanged_event = %{
      challenger: <<122, 232, 25, 13, 153, 104, 203, 179, 181, 46, 86, 165, 107, 44, 212, 205, 94, 21, 164, 79>>,
      competitor_position:
        115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935,
      eth_height: 406,
      event_signature: "InFlightExitChallenged(address,bytes32,uint256)",
      log_index: 0,
      root_chain_txhash:
        <<217, 227, 179, 170, 255, 129, 86, 218, 184, 176, 4, 136, 45, 59, 206, 131, 75, 168, 66, 201, 93, 239, 247,
          236, 151, 218, 143, 148, 47, 135, 10, 180>>,
      tx_hash:
        <<117, 50, 82, 142, 194, 36, 57, 169, 161, 237, 95, 79, 206, 108, 214, 109, 113, 98, 90, 221, 98, 2, 206, 251,
          151, 12, 16, 208, 79, 45, 80, 145>>
    }

    assert Encode.make_it_readable!(in_flight_exit_challanged_event) == %{
             challenger: "0x7ae8190d9968cbb3b52e56a56b2cd4cd5e15a44f",
             competitor_position:
               115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935,
             eth_height: 406,
             event_signature: "InFlightExitChallenged(address,bytes32,uint256)",
             log_index: 0,
             root_chain_txhash: "0xd9e3b3aaff8156dab8b004882d3bce834ba842c95deff7ec97da8f942f870ab4",
             tx_hash: "0x7532528ec22439a9a1ed5f4fce6cd66d71625add6202cefb970c10d04f2d5091"
           }
  end

  test "if exit challenged can be decoded " do
    exit_challenged_event = %{
      eth_height: 287,
      event_signature: "ExitChallenged(uint256)",
      log_index: 0,
      root_chain_txhash:
        <<66, 82, 85, 28, 152, 229, 144, 134, 61, 240, 143, 214, 56, 156, 97, 106, 171, 81, 16, 56, 48, 106, 184, 247,
          130, 36, 168, 45, 21, 7, 3, 37>>,
      utxo_pos: 1_000_000_000_000
    }

    assert Encode.make_it_readable!(exit_challenged_event) == %{
             eth_height: 287,
             event_signature: "ExitChallenged(uint256)",
             log_index: 0,
             root_chain_txhash: "0x4252551c98e590863df08fd6389c616aab511038306ab8f78224a82d15070325",
             utxo_pos: 1_000_000_000_000
           }
  end

  test "if in flight exit challenge responded can be decoded" do
    in_flight_exit_challenge_responded_event = %{
      challenge_position: 1_000_000_000_000,
      challenger: <<24, 230, 136, 50, 159, 249, 214, 25, 113, 8, 166, 102, 25, 145, 44, 218, 93, 158, 161, 99>>,
      eth_height: 293,
      event_signature: "InFlightExitChallengeResponded(address,bytes32,uint256)",
      log_index: 0,
      root_chain_txhash:
        <<63, 182, 54, 98, 165, 47, 220, 5, 212, 113, 254, 217, 43, 101, 201, 197, 58, 155, 13, 153, 11, 123, 174, 252,
          227, 24, 166, 228, 250, 108, 213, 23>>,
      tx_hash:
        <<230, 15, 66, 108, 188, 55, 20, 186, 114, 53, 223, 36, 2, 123, 242, 150, 212, 213, 42, 26, 12, 179, 109, 70,
          214, 200, 138, 57, 64, 249, 141, 107>>
    }

    assert Encode.make_it_readable!(in_flight_exit_challenge_responded_event) == %{
             challenge_position: 1_000_000_000_000,
             challenger: "0x18e688329ff9d6197108a66619912cda5d9ea163",
             eth_height: 293,
             event_signature: "InFlightExitChallengeResponded(address,bytes32,uint256)",
             log_index: 0,
             root_chain_txhash: "0x3fb63662a52fdc05d471fed92b65c9c53a9b0d990b7baefce318a6e4fa6cd517",
             tx_hash: "0xe60f426cbc3714ba7235df24027bf296d4d52a1a0cb36d46d6c88a3940f98d6b"
           }
  end

  test "if challenge in flight exit not cannonical can be decoded" do
    eth_tx_input_event = %{
      competing_tx:
        <<248, 116, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 59,
          154, 202, 0, 238, 237, 1, 235, 148, 130, 28, 224, 68, 235, 159, 239, 63, 140, 241, 0, 192, 44, 230, 131, 216,
          224, 52, 2, 224, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 128, 160, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
      competing_tx_input_index: 0,
      competing_tx_pos: 0,
      competing_tx_sig:
        <<213, 14, 110, 137, 144, 125, 5, 4, 94, 64, 55, 85, 66, 96, 210, 166, 41, 110, 42, 187, 199, 54, 83, 228, 31,
          85, 4, 44, 153, 33, 56, 182, 104, 35, 67, 129, 11, 98, 78, 229, 81, 4, 199, 65, 155, 47, 3, 187, 179, 69, 65,
          239, 135, 219, 72, 233, 93, 232, 14, 157, 74, 187, 190, 63, 28>>,
      in_flight_input_index: 0,
      in_flight_tx:
        <<248, 163, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 59,
          154, 202, 0, 248, 92, 237, 1, 235, 148, 140, 7, 214, 39, 36, 232, 102, 145, 82, 184, 199, 23, 67, 29, 135,
          188, 216, 208, 23, 89, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 237, 1, 235, 148,
          140, 7, 214, 39, 36, 232, 102, 145, 82, 184, 199, 23, 67, 29, 135, 188, 216, 208, 23, 89, 148, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
      input_tx_bytes:
        <<248, 83, 1, 192, 238, 237, 1, 235, 148, 140, 7, 214, 39, 36, 232, 102, 145, 82, 184, 199, 23, 67, 29, 135,
          188, 216, 208, 23, 89, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 128, 160, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
      input_utxo_pos: 1_000_000_000
    }

    assert Encode.make_it_readable!(eth_tx_input_event) == %{
             competing_tx:
               "0xf87401e1a0000000000000000000000000000000000000000000000000000000003b9aca00eeed01eb94821ce044eb9fef3f8cf100c02ce683d8e03402e09400000000000000000000000000000000000000000980a00000000000000000000000000000000000000000000000000000000000000000",
             competing_tx_input_index: 0,
             competing_tx_pos: 0,
             competing_tx_sig:
               "0xd50e6e89907d05045e4037554260d2a6296e2abbc73653e41f55042c992138b6682343810b624ee55104c7419b2f03bbb34541ef87db48e95de80e9d4abbbe3f1c",
             in_flight_input_index: 0,
             in_flight_tx:
               "0xf8a301e1a0000000000000000000000000000000000000000000000000000000003b9aca00f85ced01eb948c07d62724e8669152b8c717431d87bcd8d0175994000000000000000000000000000000000000000005ed01eb948c07d62724e8669152b8c717431d87bcd8d017599400000000000000000000000000000000000000000480a00000000000000000000000000000000000000000000000000000000000000000",
             input_tx_bytes:
               "0xf85301c0eeed01eb948c07d62724e8669152b8c717431d87bcd8d017599400000000000000000000000000000000000000000a80a00000000000000000000000000000000000000000000000000000000000000000",
             input_utxo_pos: 1_000_000_000
           }
  end

  test "if in flight exit input/output blocked can be decoded " do
    in_flight_exit_output_blocked_event = %{
      challenger: <<213, 8, 156, 250, 64, 58, 96, 49, 161, 243, 131, 189, 70, 126, 152, 14, 208, 189, 92, 186>>,
      eth_height: 438,
      event_signature: "InFlightExitOutputBlocked(address,bytes32,uint16)",
      log_index: 0,
      output_index: 1,
      root_chain_txhash:
        <<152, 71, 150, 186, 105, 123, 83, 43, 230, 36, 2, 153, 144, 252, 109, 79, 114, 228, 225, 67, 76, 246, 141, 207,
          59, 5, 179, 75, 121, 135, 196, 104>>,
      tx_hash:
        <<42, 63, 46, 245, 8, 132, 225, 35, 163, 42, 44, 64, 216, 103, 88, 232, 254, 91, 130, 169, 162, 184, 46, 44, 8,
          73, 190, 111, 19, 201, 87, 2>>,
      omg_data: %{piggyback_type: :output}
    }

    assert Encode.make_it_readable!(in_flight_exit_output_blocked_event) == %{
             challenger: "0xd5089cfa403a6031a1f383bd467e980ed0bd5cba",
             eth_height: 438,
             event_signature: "InFlightExitOutputBlocked(address,bytes32,uint16)",
             log_index: 0,
             omg_data: %{piggyback_type: :output},
             output_index: 1,
             root_chain_txhash: "0x984796ba697b532be624029990fc6d4f72e4e1434cf68dcf3b05b34b7987c468",
             tx_hash: "0x2a3f2ef50884e123a32a2c40d86758e8fe5b82a9a2b82e2c0849be6f13c95702"
           }
  end

  test "if in flight exit started can be decoded" do
    in_flight_exit_started_event = %{
      eth_height: 726,
      event_signature: "InFlightExitStarted(address,bytes32)",
      initiator: <<44, 106, 159, 66, 49, 128, 37, 205, 102, 39, 186, 242, 28, 70, 130, 1, 98, 32, 32, 223>>,
      log_index: 0,
      root_chain_txhash:
        <<240, 228, 74, 240, 210, 100, 67, 185, 229, 19, 60, 100, 245, 167, 31, 6, 164, 212, 208, 212, 12, 94, 116, 18,
          181, 234, 13, 252, 178, 241, 161, 51>>,
      tx_hash:
        <<79, 70, 5, 59, 93, 245, 133, 9, 76, 198, 82, 221, 216, 195, 101, 150, 42, 56, 137, 194, 5, 53, 146, 241, 131,
          49, 185, 90, 125, 255, 98, 14>>
    }

    assert Encode.make_it_readable!(in_flight_exit_started_event) == %{
             eth_height: 726,
             event_signature: "InFlightExitStarted(address,bytes32)",
             initiator: "0x2c6a9f42318025cd6627baf21c468201622020df",
             log_index: 0,
             root_chain_txhash: "0xf0e44af0d26443b9e5133c64f5a71f06a4d4d0d40c5e7412b5ea0dfcb2f1a133",
             tx_hash: "0x4f46053b5df585094cc652ddd8c365962a3889c2053592f18331b95a7dff620e"
           }
  end

  test "if start in flight exit can be decoded " do
    in_flight_exit_start_event = %{
      in_flight_tx:
        <<248, 124, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 210,
          32, 127, 180, 0, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18, 141, 145, 248, 79, 186,
          190, 47, 160, 172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 69, 99, 145, 130, 68,
          244, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0>>,
      in_flight_tx_sigs: [
        <<52, 191, 197, 222, 130, 0, 246, 100, 25, 133, 115, 123, 250, 19, 77, 122, 226, 50, 133, 34, 71, 195, 27, 188,
          147, 104, 200, 235, 121, 231, 64, 251, 107, 58, 88, 55, 118, 117, 53, 9, 224, 81, 93, 0, 167, 62, 195, 202,
          233, 207, 237, 254, 185, 95, 207, 246, 144, 69, 242, 160, 58, 161, 96, 70, 28>>
      ],
      input_inclusion_proofs: [
        <<243, 154, 134, 159, 98, 231, 92, 245, 240, 191, 145, 70, 136, 166, 178, 137, 202, 242, 4, 148, 53, 216, 230,
          140, 92, 94, 109, 5, 228, 73, 19, 243, 78, 213, 192, 45, 109, 72, 200, 147, 36, 134, 201, 157, 58, 217, 153,
          229, 216, 148, 157, 195, 190, 59, 48, 88, 204, 41, 121, 105, 12, 62, 58, 98, 28, 121, 43, 20, 191, 102, 248,
          42, 243, 111, 0, 245, 251, 167, 1, 79, 160, 193, 226, 255, 60, 124, 39, 59, 254, 82, 60, 26, 207, 103, 220,
          63, 95, 160, 128, 166, 134, 165, 160, 208, 92, 61, 72, 34, 253, 84, 214, 50, 220, 156, 192, 75, 22, 22, 4,
          110, 186, 44, 228, 153, 235, 154, 247, 159, 94, 185, 73, 105, 10, 4, 4, 171, 244, 206, 186, 252, 124, 255,
          250, 56, 33, 145, 183, 221, 158, 125, 247, 120, 88, 30, 111, 183, 142, 250, 179, 95, 211, 100, 201, 213, 218,
          218, 212, 86, 155, 109, 212, 127, 127, 234, 186, 250, 53, 113, 248, 66, 67, 68, 37, 84, 131, 53, 172, 110,
          105, 13, 208, 113, 104, 216, 188, 91, 119, 151, 156, 26, 103, 2, 51, 79, 82, 159, 87, 131, 247, 158, 148, 47,
          210, 205, 3, 246, 229, 90, 194, 207, 73, 110, 132, 159, 222, 156, 68, 111, 171, 70, 168, 210, 125, 177, 227,
          16, 15, 39, 90, 119, 125, 56, 91, 68, 227, 203, 192, 69, 202, 186, 201, 218, 54, 202, 224, 64, 173, 81, 96,
          130, 50, 76, 150, 18, 124, 242, 159, 69, 53, 235, 91, 126, 186, 207, 226, 161, 214, 211, 170, 184, 236, 4,
          131, 211, 32, 121, 168, 89, 255, 112, 249, 33, 89, 112, 168, 190, 235, 177, 193, 100, 196, 116, 232, 36, 56,
          23, 76, 142, 235, 111, 188, 140, 180, 89, 75, 136, 201, 68, 143, 29, 64, 176, 155, 234, 236, 172, 91, 69, 219,
          110, 65, 67, 74, 18, 43, 105, 92, 90, 133, 134, 45, 142, 174, 64, 179, 38, 143, 111, 55, 228, 20, 51, 123,
          227, 142, 186, 122, 181, 187, 243, 3, 208, 31, 75, 122, 224, 127, 215, 62, 220, 47, 59, 224, 94, 67, 148, 138,
          52, 65, 138, 50, 114, 80, 156, 67, 194, 129, 26, 130, 30, 92, 152, 43, 165, 24, 116, 172, 125, 201, 221, 121,
          168, 12, 194, 240, 95, 111, 102, 76, 157, 187, 46, 69, 68, 53, 19, 125, 160, 108, 228, 77, 228, 85, 50, 165,
          106, 58, 112, 7, 162, 208, 198, 180, 53, 247, 38, 249, 81, 4, 191, 166, 231, 7, 4, 111, 193, 84, 186, 233, 24,
          152, 208, 58, 26, 10, 198, 249, 180, 94, 71, 22, 70, 226, 85, 90, 199, 158, 63, 232, 126, 177, 120, 30, 38,
          242, 5, 0, 36, 12, 55, 146, 116, 254, 145, 9, 110, 96, 209, 84, 90, 128, 69, 87, 31, 218, 185, 181, 48, 208,
          214, 231, 232, 116, 110, 120, 191, 159, 32, 244, 232, 111, 6>>
      ],
      input_txs: [
        <<248, 91, 1, 192, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18, 141, 145, 248, 79, 186,
          190, 47, 160, 172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 138, 199, 35, 4, 137,
          232, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0>>
      ],
      input_utxos_pos: [2_002_000_000_000]
    }

    assert Encode.make_it_readable!(in_flight_exit_start_event) == %{
             in_flight_tx:
               "0xf87c01e1a0000000000000000000000000000000000000000000000000000001d2207fb400f6f501f394764ef8031c11f8dc2a5c128d91f84fbabe2fa0ac940000000000000000000000000000000000000000884563918244f4000080a00000000000000000000000000000000000000000000000000000000000000000",
             in_flight_tx_sigs: [
               "0x34bfc5de8200f6641985737bfa134d7ae232852247c31bbc9368c8eb79e740fb6b3a583776753509e0515d00a73ec3cae9cfedfeb95fcff69045f2a03aa160461c"
             ],
             input_inclusion_proofs: [
               "0xf39a869f62e75cf5f0bf914688a6b289caf2049435d8e68c5c5e6d05e44913f34ed5c02d6d48c8932486c99d3ad999e5d8949dc3be3b3058cc2979690c3e3a621c792b14bf66f82af36f00f5fba7014fa0c1e2ff3c7c273bfe523c1acf67dc3f5fa080a686a5a0d05c3d4822fd54d632dc9cc04b1616046eba2ce499eb9af79f5eb949690a0404abf4cebafc7cfffa382191b7dd9e7df778581e6fb78efab35fd364c9d5dadad4569b6dd47f7feabafa3571f842434425548335ac6e690dd07168d8bc5b77979c1a6702334f529f5783f79e942fd2cd03f6e55ac2cf496e849fde9c446fab46a8d27db1e3100f275a777d385b44e3cbc045cabac9da36cae040ad516082324c96127cf29f4535eb5b7ebacfe2a1d6d3aab8ec0483d32079a859ff70f9215970a8beebb1c164c474e82438174c8eeb6fbc8cb4594b88c9448f1d40b09beaecac5b45db6e41434a122b695c5a85862d8eae40b3268f6f37e414337be38eba7ab5bbf303d01f4b7ae07fd73edc2f3be05e43948a34418a3272509c43c2811a821e5c982ba51874ac7dc9dd79a80cc2f05f6f664c9dbb2e454435137da06ce44de45532a56a3a7007a2d0c6b435f726f95104bfa6e707046fc154bae91898d03a1a0ac6f9b45e471646e2555ac79e3fe87eb1781e26f20500240c379274fe91096e60d1545a8045571fdab9b530d0d6e7e8746e78bf9f20f4e86f06"
             ],
             input_txs: [
               "0xf85b01c0f6f501f394764ef8031c11f8dc2a5c128d91f84fbabe2fa0ac940000000000000000000000000000000000000000888ac7230489e8000080a00000000000000000000000000000000000000000000000000000000000000000"
             ],
             input_utxos_pos: [2_002_000_000_000]
           }
  end

  test "if in flight exit finalized can be decoded" do
    in_flight_exit_finalized_event = %{
      eth_height: 335,
      event_signature: "InFlightExitOutputWithdrawn(uint168,uint16)",
      in_flight_exit_id: 289_509_717_723_506_568_833_816_412_236_561_243_950_769_583_247_992,
      log_index: 1,
      output_index: 1,
      root_chain_txhash:
        <<80, 248, 10, 40, 199, 180, 94, 87, 0, 214, 231, 86, 164, 157, 76, 108, 238, 189, 92, 74, 82, 133, 178, 138,
          190, 185, 112, 88, 201, 65, 185, 102>>,
      omg_data: %{piggyback_type: :output}
    }

    assert Encode.make_it_readable!(in_flight_exit_finalized_event) == %{
             eth_height: 335,
             event_signature: "InFlightExitOutputWithdrawn(uint168,uint16)",
             in_flight_exit_id: 289_509_717_723_506_568_833_816_412_236_561_243_950_769_583_247_992,
             log_index: 1,
             omg_data: %{piggyback_type: :output},
             output_index: 1,
             root_chain_txhash: "0x50f80a28c7b45e5700d6e756a49d4c6ceebd5c4a5285b28abeb97058c941b966"
           }
  end

  test "if exit started can be decoded" do
    exit_started_event = %{
      eth_height: 759,
      event_signature: "ExitStarted(address,uint168)",
      exit_id: 81_309_820_288_462_349_357_922_495_476_773_313_169_175_330_970_420,
      log_index: 1,
      owner: <<8, 133, 129, 36, 179, 184, 128, 198, 139, 54, 15, 211, 25, 204, 97, 218, 39, 84, 94, 154>>,
      root_chain_txhash:
        <<74, 130, 72, 184, 138, 23, 178, 190, 76, 96, 134, 161, 152, 70, 34, 222, 26, 96, 221, 163, 201, 221, 158, 206,
          30, 249, 126, 209, 142, 250, 2, 140>>
    }

    assert Encode.make_it_readable!(exit_started_event) == %{
             eth_height: 759,
             event_signature: "ExitStarted(address,uint168)",
             exit_id: 81_309_820_288_462_349_357_922_495_476_773_313_169_175_330_970_420,
             log_index: 1,
             owner: "0x08858124b3b880c68b360fd319cc61da27545e9a",
             root_chain_txhash: "0x4a8248b88a17b2be4c6086a1984622de1a60dda3c9dd9ece1ef97ed18efa028c"
           }
  end

  test "if start standard exit can be decoded" do
    start_standard_exit_event = %{
      output_tx:
        <<248, 91, 1, 192, 246, 245, 1, 243, 148, 8, 133, 129, 36, 179, 184, 128, 198, 139, 54, 15, 211, 25, 204, 97,
          218, 39, 84, 94, 154, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 13, 224, 182, 179,
          167, 100, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0>>,
      utxo_pos: 2_001_000_000_000
    }

    assert Encode.make_it_readable!(start_standard_exit_event) == %{
             output_tx:
               "0xf85b01c0f6f501f39408858124b3b880c68b360fd319cc61da27545e9a940000000000000000000000000000000000000000880de0b6b3a764000080a00000000000000000000000000000000000000000000000000000000000000000",
             utxo_pos: 2_001_000_000_000
           }
  end
end
