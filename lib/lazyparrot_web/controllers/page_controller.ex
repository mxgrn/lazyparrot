defmodule LazyparrotWeb.PageController do
  use LazyparrotWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
