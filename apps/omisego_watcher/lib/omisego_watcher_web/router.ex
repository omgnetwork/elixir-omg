defmodule OmiseGOWatcherWeb.Router do
  use OmiseGOWatcherWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OmiseGOWatcherWeb do
    get "/account/utxo", Controller.Utxo, :available
  end

  scope "/transactions", OmiseGOWatcherWeb do
    get "/:id", Controller.Transaction, :get_transaction
  end

end
