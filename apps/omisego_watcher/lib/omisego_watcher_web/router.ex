defmodule OmiseGOWatcherWeb.Router do
  use OmiseGOWatcherWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", OmiseGOWatcherWeb do
    get("/account/utxo", Controller.Utxo, :available)
    get("/account/utxo/compose_exit", Controller.Utxo, :compose_utxo_exit)
    get("/status", Controller.Status, :get)
  end

  scope "/transactions", OmiseGOWatcherWeb do
    get("/:id", Controller.Transaction, :get)
  end
end
