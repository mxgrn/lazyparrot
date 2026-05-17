defmodule LazyparrotWeb.TelegramController do
  use LazyparrotWeb, :controller

  alias Lazyparrot.Telegram.Bot

  def webhook(conn, params) do
    Bot.handle_update(conn.assigns[:current_user], params)
    json(conn, %{ok: true})
  end
end
