defmodule Lazyparrot.Repo do
  use Ecto.Repo,
    otp_app: :lazyparrot,
    adapter: Ecto.Adapters.Postgres
end
