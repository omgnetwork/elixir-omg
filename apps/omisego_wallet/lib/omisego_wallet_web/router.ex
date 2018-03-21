defmodule OmisegoWalletWeb.Router do
  use OmisegoWalletWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OmisegoWalletWeb do
    get "/account/utxo", Controller.Utxo, :available

  end

end
