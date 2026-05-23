defmodule Lazyparrot.Telegram.Bot do
  use Gettext, backend: Lazyparrot.LlmGettext

  alias Lazyparrot.Cards
  alias Lazyparrot.Telegram
  alias Lazyparrot.Telegram.BotInfo
  alias Lazyparrot.Telegram.Flows.CardCreation
  alias Lazyparrot.Telegram.Reviews
  alias Lazyparrot.Users

  require BotInfo

  def handle_update(nil, _params), do: :ok

  def handle_update(user, %{
        "callback_query" => %{"data" => data, "message" => %{"message_id" => message_id}}
      }) do
    {method, payload} = parse_callback_data(data)
    handle_callback(user, method, payload, message_id)
  end

  def handle_update(user, %{"message" => %{"text" => "/" <> command}}) do
    handle_command(user, command)
  end

  def handle_update(user, %{"message" => %{"text" => text}}) do
    handle_text(user, text)
  end

  def handle_update(_user, _params), do: :ok

  defp handle_command(user, "review" <> _) do
    if user.current_flow, do: Users.reset_flow!(user)
    Reviews.start(user)
  end

  defp handle_command(user, "start" <> _) do
    Telegram.send_message(
      user.telegram_id,
      gettext(
        "You have no flashcards yet. Send me a word or phrase you'd like to learn, so we could make a flashcard!"
      )
    )
  end

  defp handle_command(user, "help" <> _) do
    text =
      gettext("""
      <b>How to add new flashcards</b>

      Send me a word or phrase you want to learn, and I'll suggest a flashcard for it.

      <b>How to review flashcards</b>

      Use /review to start. I'll show you the question — try to remember the answer, then rate how well you recalled it.

      <b>Available commands</b>
      """) <> gettext(BotInfo.commands())

    Telegram.send_message(user.telegram_id, text)
  end

  defp handle_command(user, "stats" <> _) do
    %{mature: mature, active: active, new: new} = Cards.count_by_status(user.id)
    due = Cards.count_due(user.id)

    text =
      gettext(
        """
        📊 <b>Your stats</b>

        ✅ Mature: %{mature}
        ⏰ Active: %{active}
        🌱 New: %{new}
        📬 Due for review: %{due}\
        """,
        mature: mature,
        active: active,
        new: new,
        due: due
      )

    Telegram.send_message(user.telegram_id, text)
  end

  defp handle_command(_user, _), do: :ok

  defp handle_text(user, text) do
    case user.current_flow do
      nil ->
        CardCreation.start(user, text)

      flow_module_string ->
        module = String.to_existing_atom(flow_module_string)
        module.handle_message(user, text)
    end
  end

  defp handle_callback(user, "show", payload, message_id) do
    Reviews.show_answer(user, payload, message_id)
  end

  defp handle_callback(user, "rate", payload, message_id) do
    Reviews.handle_rating(user, payload["id"], payload["r"], message_id)
  end

  defp handle_callback(user, "del", payload, message_id) do
    Reviews.handle_delete(user, payload["id"], payload["p"], message_id)
  end

  defp handle_callback(user, "del_y", payload, message_id) do
    Reviews.handle_delete_confirm(user, payload["id"], message_id)
  end

  defp handle_callback(user, "del_n", payload, message_id) do
    Reviews.handle_delete_cancel(user, payload["id"], payload["p"], message_id)
  end

  defp handle_callback(user, "crev", card_id, message_id) do
    CardCreation.handle_reverse(user, card_id, message_id)
  end

  defp handle_callback(user, "cdel", card_id, message_id) do
    CardCreation.handle_delete(user, card_id, message_id)
  end

  defp handle_callback(user, "cdel_y", card_id, message_id) do
    CardCreation.handle_delete_confirm(user, card_id, message_id)
  end

  defp handle_callback(user, "cdel_n", card_id, message_id) do
    CardCreation.handle_delete_cancel(user, card_id, message_id)
  end

  defp handle_callback(user, "start_review", _payload, _message_id) do
    Reviews.start(user)
  end

  defp handle_callback(user, "pause_reminders", _payload, _message_id) do
    Reviews.pause_reminders(user)
  end

  defp handle_callback(_user, _method, _payload, _message_id), do: :ok

  defp parse_callback_data(data) do
    case String.split(data, ":", parts: 2) do
      [method, payload] -> {method, Jason.decode!(payload)}
      [method] -> {method, %{}}
    end
  end
end
