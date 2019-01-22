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

defmodule OMG.Watcher.Web.Controller.Utxo do
  @moduledoc """
  Operations related to utxo.
  Modify the state in the database.
  """

  use OMG.Watcher.Web, :controller
  use PhoenixSwagger

  alias OMG.API.Utxo.Position
  alias OMG.Watcher.API

  def get_utxo_exit(conn, params) do
    with {:ok, utxo_pos} <- expect(params, "utxo_pos", :pos_integer),
         utxo <- Position.decode(utxo_pos) do
      utxo
      |> API.Utxo.compose_utxo_exit()
      |> api_response(conn, :utxo_exit)
    end
  end

  def swagger_definitions do
    %{
      UtxoExit:
        swagger_schema do
          title("Utxo exit")
          description("Can be submitted to rootchain to initiate an utxo exit")

          properties do
            utxo_pos(:integer, "Utxo position", required: true)
            txbytes(:string, "Signed hash of transaction", required: true)

            proof(
              :string,
              "Merkle proof that transaction that produced the utxo is contained in a child chain block",
              required: true
            )

            sigs(:string, "Signatures of users that confirmed transaction", required: true)
          end

          example(%{
            utxo_pos: 10_001_001,
            txbytes:
              "F84701018080808094000000000000000000000000000000000000000094D27EB36B73F275E3F7CD20A510710F763DE3BF366E94000000000000000000000000000000000000000080",
            proof:
              "CEDB8B31D1E4CB72EC267A8B27C42C4D9982C3F3950D88003F44B3A797202D848025356282CA1C28CBD51FBF7D8E9187AA85F628D054B2C2233AA83BCAEF1F0EB4C11951957C6F8F642C4AF61CD6B24640FEC6DC7FC607EE8206A99E92410D3021DDB9A356815C3FAC1026B6DEC5DF3124AFBADB485C9BA5A3E3398A04B7BA85E58769B32A1BEAF1EA27375A44095A0D1FB664CE2DD358E7FCBFB78C26A193440EB01EBFC9ED27500CD4DFC979272D1F0913CC9F66540D7E8005811109E1CF2D887C22BD8750D34016AC3C66B5FF102DACDD73F6B014E710B51E8022AF9A1968FFD70157E48063FC33C97A050F7F640233BF646CC98D9524C6B92BCF3AB56F839867CC5F7F196B93BAE1E27E6320742445D290F2263827498B54FEC539F756AFCEFAD4E508C098B9A7E1D8FEB19955FB02BA9675585078710969D3440F5054E0F9DC3E7FE016E050EFF260334F18A5D4FE391D82092319F5964F2E2EB7C1C3A5F8B13A49E282F609C317A833FB8D976D11517C571D1221A265D25AF778ECF8923490C6CEEB450AECDC82E28293031D10C7D73BF85E57BF041A97360AA2C5D99CC1DF82D9C4B87413EAE2EF048F94B4D3554CEA73D92B0F7AF96E0271C691E2BB5C67ADD7C6CAF302256ADEDF7AB114DA0ACFE870D449A3A489F781D659E8BECCDA7BCE9F4E8618B6BD2F4132CE798CDC7A60E7E1460A7299E3C6342A579626D2",
            sigs:
              "7C29FB8327F60BBFC6201DF2FBAAA8D22E5C0CA3D1EB5FF0D37ECDAF61E507FE77DED514AA42A622E5682BF692B33E60D292425C531109841C67B5BD86876CDE1C0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
          })
        end
    }
  end

  swagger_path :get_utxo_exit do
    post("/utxo.get_exit_data")
    summary("Responds with exit for a given utxo")

    parameters do
      utxo_pos(:body, :integer, "Position of the exiting utxo", required: true)
    end

    response(200, "OK", Schema.ref(:UtxoExit))
  end
end
