defmodule Lazyparrot.Telegram do
  require Logger

  def request(method, params) do
    token()
    |> Gramex.Api.request(method, params,
      base_url: Application.get_env(:lazyparrot, :telegram_bot)[:base_url] || "https://api.telegram.org"
    )
    |> log_errors(method, params)
  end

  def send_message(chat_id, text, opts \\ []) do
    params = %{chat_id: chat_id, text: text, parse_mode: "HTML"}

    params =
      if opts[:reply_markup],
        do: Map.put(params, :reply_markup, opts[:reply_markup]),
        else: params

    request("sendMessage", params)
  end

  def edit_message(chat_id, message_id, text, opts \\ []) do
    params = %{chat_id: chat_id, message_id: message_id, text: text, parse_mode: "HTML"}

    params =
      if opts[:reply_markup],
        do: Map.put(params, :reply_markup, opts[:reply_markup]),
        else: params

    request("editMessageText", params)
  end

  def delete_message(chat_id, message_id) do
    request("deleteMessage", %{chat_id: chat_id, message_id: message_id})
  end

  @doc """
  Escapes user-provided text for interpolation into `parse_mode: "HTML"`
  messages, so stray `<`, `>`, or `&` don't make Telegram reject the request.
  """
  def escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp token do
    Application.get_env(:lazyparrot, :telegram_bot)[:token]
  end

  defp log_errors({:invalid_request, description}, method, params) do
    Logger.error(
      "Telegram API rejected #{method} (chat_id: #{inspect(params[:chat_id])}): #{description}"
    )

    {:error, description}
  end

  defp log_errors({:error, description}, method, params) do
    Logger.error(
      "Telegram API #{method} failed (chat_id: #{inspect(params[:chat_id])}): #{description}"
    )

    {:error, description}
  end

  # {:ok, result}, :ok, and {:blocked, description} pass through untouched;
  # a blocked bot is routine user behavior, not an error worth alerting on.
  defp log_errors(result, _method, _params), do: result
end
