defmodule Front.Repo do
  use Ecto.Repo,
    otp_app: :front,
    adapter: Ecto.Adapters.Postgres
end
