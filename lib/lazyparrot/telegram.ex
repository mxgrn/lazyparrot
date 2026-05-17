defmodule Lazyparrot.Telegram do
  def request(method, params) do
    Gramex.Api.request(token(), method, params)
  end

  def send_message(chat_id, text, opts \\ []) do
    params = %{chat_id: chat_id, text: text, parse_mode: "HTML"}
    params = if opts[:reply_markup], do: Map.put(params, :reply_markup, opts[:reply_markup]), else: params
    request("sendMessage", params)
  end

  def edit_message(chat_id, message_id, text, opts \\ []) do
    params = %{chat_id: chat_id, message_id: message_id, text: text, parse_mode: "HTML"}
    params = if opts[:reply_markup], do: Map.put(params, :reply_markup, opts[:reply_markup]), else: params
    request("editMessageText", params)
  end

  def delete_message(chat_id, message_id) do
    request("deleteMessage", %{chat_id: chat_id, message_id: message_id})
  end

  defp token do
    Application.get_env(:lazyparrot, :telegram_bot)[:token]
  end
end
