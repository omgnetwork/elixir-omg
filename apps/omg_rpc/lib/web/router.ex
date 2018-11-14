defmodule OMG.RPC.Web.Router do
  use OMG.RPC.Web, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :omg_rpc, swagger_file: "swagger.json")
  end

  scope "/", OMG.RPC.Web do
    pipe_through(:api)

    post("/block.get", Controller.Block, :get_block)
  end

  def swagger_info do
    %{
      info: %{
        version: "1.0",
        title: "OMG API"
      }
    }
  end
end
