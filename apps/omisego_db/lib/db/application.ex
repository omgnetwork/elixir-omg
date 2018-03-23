defmodule OmiseGO.DB.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    db_path = Application.get_env(:omisego_db, :leveldb_path)
    server_module = Application.get_env(:omisego_db, :server_module)
    server_name = Application.get_env(:omisego_db, :server_name)
    children = [
      {server_module, name: server_name, db_path: db_path},
    ]

    opts = [strategy: :one_for_one, name: OmiseGO.DB.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
