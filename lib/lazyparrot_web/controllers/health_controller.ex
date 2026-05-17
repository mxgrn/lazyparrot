defmodule LazyparrotWeb.HealthController do
  use LazyparrotWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
