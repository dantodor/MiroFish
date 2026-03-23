defmodule Miroex.Repo do
  use Ecto.Repo,
    otp_app: :miroex,
    adapter: Ecto.Adapters.Postgres
end
