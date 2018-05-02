defmodule OmiseGOWatcherWeb.Router do
  use OmiseGOWatcherWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/account/utxo", OmiseGOWatcherWeb do
    get "/", Controller.Utxo, :available
    get "/compose_exit", Controller.Utxo, :compose_utxo_exit
  end

  scope "/transactions", OmiseGOWatcherWeb do
    get "/:id", Controller.Transaction, :get
  end

end
