defmodule Lazyparrot.Telegram.Reviews do
  use Gettext, backend: Lazyparrot.LlmGettext

  alias Lazyparrot.Cards
  alias Lazyparrot.Telegram

  def start(user) do
    case Cards.next_due(user.id) do
      nil ->
        if Cards.count(user.id) > 0 do
          Telegram.send_message(
            user.telegram_id,
            "✅ " <> gettext("You have no cards to review. Enjoy your break—or add more cards!")
          )
        else
          Telegram.send_message(
            user.telegram_id,
            gettext("You have no flashcards yet. Send me a word or phrase you'd like to learn, so we could make a flashcard!")
          )
        end

      card ->
        send_question(user, card)
    end
  end

  def show_answer(user, card_id, message_id, opts \\ []) do
    confirm_delete = Keyword.get(opts, :confirm_delete, false)

    case Cards.get_for_user(card_id, user.id) do
      nil ->
        Telegram.edit_message(user.telegram_id, message_id, gettext("This card no longer exists."))

      card ->
        hint = "\n\n💁 " <> gettext("How easy was it to recall the answer?")

        Telegram.edit_message(
          user.telegram_id,
          message_id,
          "<b>#{card.front}</b>\n\n#{card.back}" <> hint,
          reply_markup: %{
            inline_keyboard: [
              [rating_button(card.id, "again", "👎 " <> pgettext("button", "Could not recall"))],
              [rating_button(card.id, "hard", "😅 " <> pgettext("button", "Hard"))],
              [rating_button(card.id, "good", "😀 " <> pgettext("button", "Fine"))],
              [rating_button(card.id, "easy", "😎 " <> pgettext("button", "Easy"))],
              delete_buttons(card.id, "a", confirm_delete)
            ]
          }
        )
    end
  end

  def handle_rating(user, card_id, rating_string, message_id) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        Telegram.edit_message(
          user.telegram_id,
          message_id,
          gettext("This card was not found, it might have been deleted.")
        )

      card ->
        rating = String.to_atom(rating_string)
        ex_fsrs = Cards.to_ex_fsrs(card)
        {updated_fsrs, _log} = ExFsrs.review_card(ex_fsrs, rating)
        Cards.update_fsrs!(card, updated_fsrs)

        case Cards.next_due(user.id) do
          nil ->
            Telegram.edit_message(
              user.telegram_id,
              message_id,
              "✅ " <> gettext("All cards reviewed. Enjoy your break!")
            )

          next_card ->
            send_question_edit(user, next_card, message_id)
        end
    end
  end

  def handle_delete(user, card_id, placement, message_id) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        Telegram.edit_message(
          user.telegram_id,
          message_id,
          gettext("This card was already deleted."),
          reply_markup: %{}
        )

      _card ->
        case placement do
          "q" -> send_question_edit(user, Cards.get_for_user(card_id, user.id), message_id, confirm_delete: true)
          "a" -> show_answer(user, card_id, message_id, confirm_delete: true)
        end
    end
  end

  def handle_delete_confirm(user, card_id, message_id) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        :ok

      card ->
        Cards.delete!(card)

        case Cards.next_due(user.id) do
          nil ->
            Telegram.edit_message(
              user.telegram_id,
              message_id,
              "✅ " <> gettext("All cards reviewed. Enjoy your break!")
            )

          next_card ->
            send_question_edit(user, next_card, message_id)
        end
    end
  end

  def handle_delete_cancel(user, card_id, placement, message_id) do
    case placement do
      "q" -> send_question_edit(user, Cards.get_for_user(card_id, user.id), message_id)
      "a" -> show_answer(user, card_id, message_id)
    end
  end

  defp send_question(user, card) do
    count = Cards.count_due(user.id)

    Telegram.send_message(
      user.telegram_id,
      question_text(card, count),
      reply_markup: question_markup(card.id)
    )
  end

  defp send_question_edit(user, card, message_id, opts \\ []) do
    confirm_delete = Keyword.get(opts, :confirm_delete, false)
    count = Cards.count_due(user.id)

    Telegram.edit_message(
      user.telegram_id,
      message_id,
      question_text(card, count),
      reply_markup: question_markup(card.id, confirm_delete)
    )
  end

  defp question_text(card, count) do
    "<b>#{card.front}</b>\n\n<i>#{gettext("Cards left: %{count}", count: count)}</i>"
  end

  defp question_markup(card_id, confirm_delete \\ false) do
    %{
      inline_keyboard: [
        [%{text: "👀 " <> pgettext("button", "Show answer"), callback_data: "show:#{card_id}"}],
        delete_buttons(card_id, "q", confirm_delete)
      ]
    }
  end

  defp delete_buttons(card_id, placement, true) do
    [
      %{
        text: "🗑️ " <> pgettext("button", "Delete"),
        callback_data: "del_y:#{Jason.encode!(%{"id" => card_id, "p" => placement})}"
      },
      %{
        text: "❌ " <> pgettext("button", "Cancel"),
        callback_data: "del_n:#{Jason.encode!(%{"id" => card_id, "p" => placement})}"
      }
    ]
  end

  defp delete_buttons(card_id, placement, false) do
    [
      %{
        text: "🗑️ " <> pgettext("button", "Delete"),
        callback_data: "del:#{Jason.encode!(%{"id" => card_id, "p" => placement})}"
      }
    ]
  end

  defp rating_button(card_id, rating, label) do
    %{text: label, callback_data: "rate:#{Jason.encode!(%{"id" => card_id, "r" => rating})}"}
  end
end
