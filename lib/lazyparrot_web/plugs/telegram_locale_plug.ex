defmodule LazyparrotWeb.Plugs.TelegramLocalePlug do
  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{telegram_language_code: locale} when is_binary(locale) and locale != "" ->
        Gettext.put_locale(locale)

      _ ->
        Gettext.put_locale("en")
    end

    conn
  end
end
