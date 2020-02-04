defmodule Engine.Repo do
  use Ecto.Repo,
    otp_app: :engine,
    adapter: Ecto.Adapters.Postgres
end
