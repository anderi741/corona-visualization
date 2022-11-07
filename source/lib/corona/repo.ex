defmodule Corona.Repo do
  use Ecto.Repo,
    otp_app: :corona,
    adapter: Ecto.Adapters.Postgres
end
