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

defmodule OMG.Watcher.Web.Controller.Challenge do
  @moduledoc """
  Handles exit challenges
  """

  use OMG.Watcher.Web, :controller
  use PhoenixSwagger

  alias OMG.API.Utxo
  require Utxo
  alias OMG.Watcher.Challenger
  alias OMG.Watcher.Web.View

  import OMG.Watcher.Web.ErrorHandler

  @doc """
  Challenges exits
  """
  def get_utxo_challenge(conn, %{"utxo_pos" => utxo_pos}) do
    {utxo_pos, ""} = Integer.parse(utxo_pos)

    utxo_pos = utxo_pos |> Utxo.Position.decode()

    Challenger.create_challenge(utxo_pos)
    |> respond(conn)
  end

  defp respond({:ok, challenge}, conn) do
    render(conn, View.Challenge, :challenge, challenge: challenge)
  end

  defp respond({:error, code}, conn) do
    handle_error(conn, code)
  end

  def swagger_definitions do
    %{
      Challenge:
        swagger_schema do
          title("Exit challenge")

          properties do
            cutxopos(:string, "Challenging utxo position", required: true)
            eutxoindex(:string, "Exiting utxo position", required: true)
            txbytes(:string, "Transaction that spends exiting utxo", required: true)
            proof(:string, "Proof that transaction is contained in a block", required: true)
            sigs(:string, "Signatures of users that participated in the challenging transaction", required: true)
          end

          example(%{
            cutxopos: "100001001",
            eutxoindex: "200001001",
            proof:
              "0000000000000000000000000000000000000000000000000000000000000000AD3228B676F7D3CD4284A5443F17F1962B36E491B30A40B2405849E597BA5FB5B4C11951957C6F8F642C4AF61CD6B24640FEC6DC7FC607EE8206A99E92410D3021DDB9A356815C3FAC1026B6DEC5DF3124AFBADB485C9BA5A3E3398A04B7BA85E58769B32A1BEAF1EA27375A44095A0D1FB664CE2DD358E7FCBFB78C26A193440EB01EBFC9ED27500CD4DFC979272D1F0913CC9F66540D7E8005811109E1CF2D887C22BD8750D34016AC3C66B5FF102DACDD73F6B014E710B51E8022AF9A1968FFD70157E48063FC33C97A050F7F640233BF646CC98D9524C6B92BCF3AB56F839867CC5F7F196B93BAE1E27E6320742445D290F2263827498B54FEC539F756AFCEFAD4E508C098B9A7E1D8FEB19955FB02BA9675585078710969D3440F5054E0F9DC3E7FE016E050EFF260334F18A5D4FE391D82092319F5964F2E2EB7C1C3A5F8B13A49E282F609C317A833FB8D976D11517C571D1221A265D25AF778ECF8923490C6CEEB450AECDC82E28293031D10C7D73BF85E57BF041A97360AA2C5D99CC1DF82D9C4B87413EAE2EF048F94B4D3554CEA73D92B0F7AF96E0271C691E2BB5C67ADD7C6CAF302256ADEDF7AB114DA0ACFE870D449A3A489F781D659E8BECCDA7BCE9F4E8618B6BD2F4132CE798CDC7A60E7E1460A7299E3C6342A579626D2",
            sigs:
              "6BFB9B2DBE3201BDC48072E69148A0ED9AF3E01D87772C8A77A478F998CEB5236B0AE64FAB3C21C078188B162D86913010A988E4B0CE68EE95D86783008FD9C71B0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            txbytes:
              "F849822AF880808080809400000000000000000000000000000000000000009489F5AD3F771617E853451A93F7A73E48CF5550D104948CE5C73FD5BEFFE0DCBCB6AFE571A2A3E73B043C03"
          })
        end,
      BadRequestError:
        swagger_schema do
          title("Bad request")
          description("Erroneous request from the user")

          properties do
            error(:string, "The message of the error raised", required: true)
          end

          example(%{
            error: "exit is valid"
          })
        end
    }
  end

  swagger_path :get_utxo_challenge do
    get("/utxo/{utxo_pos}/challenge_data")
    summary("Gets challenge for a given exit")

    parameters do
      utxo_pos(:path, :integer, "The position of the exiting utxo", required: true)
    end

    response(200, "OK", Schema.ref(:Challenge))
    response(400, "Client Error", Schema.ref(:BadRequestError))
  end
end
