defmodule Lazyparrot.Telegram.Reviews do
  use Gettext, backend: Lazyparrot.LlmGettext

  alias Lazyparrot.Cards
  alias Lazyparrot.Telegram
  alias Lazyparrot.Telegram.CardSharing
  alias Lazyparrot.Telegram.Flows.CardCreation
  alias Lazyparrot.Users
  alias Lazyparrot.Workers.ReviewReminder

  @caption_limit 1024

  def start(user) do
    ReviewReminder.schedule_reminder(user.id)

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
            gettext(
              "You have no flashcards yet. Send me a word or phrase you'd like to learn, so we could make a flashcard!"
            )
          )
        end

      card ->
        send_question(user, card)
    end
  end

  # Callbacks pass the whole callback `message` (not just its id), so that
  # `show/4` can tell a text message from a photo message.
  def show_answer(user, card_id, message, opts \\ []) do
    confirm_delete = Keyword.get(opts, :confirm_delete, false)

    case Cards.get_for_user(card_id, user.id) do
      nil ->
        show(user, message, {:text, gettext("This card no longer exists.")})

      card ->
        show(user, message, answer_view(card),
          reply_markup: %{
            inline_keyboard: [
              [rating_button(card.id, "again", "👎 " <> pgettext("button", "Could not recall"))],
              [rating_button(card.id, "hard", "😅 " <> pgettext("button", "Hard"))],
              [rating_button(card.id, "good", "😀 " <> pgettext("button", "Fine"))],
              [rating_button(card.id, "easy", "😎 " <> pgettext("button", "Easy"))],
              [CardSharing.share_button(card)],
              delete_buttons(card.id, "a", confirm_delete)
            ]
          }
        )
    end
  end

  def handle_rating(user, card_id, rating_string, message) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        show(
          user,
          message,
          {:text, gettext("This card was not found, it might have been deleted.")}
        )

      card ->
        rating = String.to_atom(rating_string)
        ex_fsrs = Cards.to_ex_fsrs(card)
        {updated_fsrs, _log} = ExFsrs.review_card(ex_fsrs, rating)
        Cards.update_fsrs!(card, updated_fsrs)

        case Cards.next_due(user.id) do
          nil ->
            show(user, message, {:text, "✅ " <> gettext("All cards reviewed. Enjoy your break!")})

          next_card ->
            send_question_edit(user, next_card, message)
        end
    end
  end

  def handle_delete(user, card_id, placement, message) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        # editing without reply_markup also removes the buttons
        show(user, message, {:text, gettext("This card was already deleted.")})

      _card ->
        case placement do
          "q" ->
            send_question_edit(user, Cards.get_for_user(card_id, user.id), message,
              confirm_delete: true
            )

          "a" ->
            show_answer(user, card_id, message, confirm_delete: true)
        end
    end
  end

  def handle_delete_confirm(user, card_id, message) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        :ok

      card ->
        Cards.delete!(card)

        case Cards.next_due(user.id) do
          nil ->
            show(user, message, {:text, "✅ " <> gettext("All cards reviewed. Enjoy your break!")})

          next_card ->
            send_question_edit(user, next_card, message)
        end
    end
  end

  def handle_delete_cancel(user, card_id, placement, message) do
    case placement do
      "q" -> send_question_edit(user, Cards.get_for_user(card_id, user.id), message)
      "a" -> show_answer(user, card_id, message)
    end
  end

  defp send_question(user, card) do
    %{to_review: to_review, new: new} = Cards.count_due_by_type(user.id)
    send_view(user, question_view(card, to_review, new), reply_markup: question_markup(card.id))
  end

  defp send_question_edit(user, card, message, opts \\ []) do
    confirm_delete = Keyword.get(opts, :confirm_delete, false)
    %{to_review: to_review, new: new} = Cards.count_due_by_type(user.id)

    show(user, message, question_view(card, to_review, new),
      reply_markup: question_markup(card.id, confirm_delete)
    )
  end

  # A view is what a review message shows: `{:text, html}`, or
  # `{:photo, file_id, caption_html}` when a card side is an image.
  defp question_view(card, to_review, new) do
    summary = "<i>#{review_summary(to_review, new)}</i>"

    card_view(card.front_image, fn shown_image ->
      [summary, bold(side_html(card.front, card.front_image, shown_image))]
    end)
  end

  # Shows the back image if there is one; else the front image, for context.
  defp answer_view(card) do
    hint = "💁 " <> gettext("How easy was it to recall the answer?")

    card_view(card.back_image || card.front_image, fn shown_image ->
      [
        bold(side_html(card.front, card.front_image, shown_image)),
        side_html(card.back, card.back_image, shown_image),
        hint
      ]
    end)
  end

  # `lines_fun` gets the image that is shown (or nil) and returns the lines of
  # the message. Falls back to text (with 🖼 markers for the images) when the
  # caption is longer than Telegram allows.
  defp card_view(nil, lines_fun), do: {:text, join_lines(lines_fun.(nil))}

  defp card_view(image, lines_fun) do
    caption = join_lines(lines_fun.(image))

    if caption_fits?(caption),
      do: {:photo, image, caption},
      else: card_view(nil, lines_fun)
  end

  # The side whose image is shown needs only its caption (if any) as text.
  defp side_html(caption, image, image), do: caption && Telegram.escape(caption)

  defp side_html(text, image, _shown_image),
    do: Telegram.escape(CardCreation.side_label(text, image))

  defp bold(nil), do: nil
  defp bold(html), do: "<b>#{html}</b>"

  defp join_lines(lines), do: lines |> Enum.reject(&is_nil/1) |> Enum.join("\n\n")

  # Telegram counts caption length in UTF-16 code units, after it parses the HTML.
  defp caption_fits?(caption_html) do
    plain =
      caption_html
      |> String.replace(~r/<[^>]*>/, "")
      |> String.replace(["&lt;", "&gt;", "&amp;"], fn
        "&lt;" -> "<"
        "&gt;" -> ">"
        "&amp;" -> "&"
      end)

    byte_size(:unicode.characters_to_binary(plain, :utf8, :utf16)) <= 2 * @caption_limit
  end

  # Telegram can't edit a text message into a photo message (or back), so when
  # the kind of message changes, delete it and send a new one.
  defp show(user, message, view, opts \\ []) do
    message_id = message["message_id"]

    case {view, Map.has_key?(message, "text")} do
      {{:text, text}, true} ->
        Telegram.edit_message(user.telegram_id, message_id, text, opts)

      {{:photo, image, caption}, false} ->
        Telegram.edit_message_media(user.telegram_id, message_id, image, caption, opts)

      _ ->
        Telegram.delete_message(user.telegram_id, message_id)
        send_view(user, view, opts)
    end
  end

  defp send_view(user, {:text, text}, opts) do
    Telegram.send_message(user.telegram_id, text, opts)
  end

  defp send_view(user, {:photo, image, caption}, opts) do
    Telegram.send_photo(user.telegram_id, image, caption, opts)
  end

  defp review_summary(0, new) do
    gettext("🌱 New cards to start learning: %{count}", count: new)
  end

  defp review_summary(to_review, _new) do
    gettext("Active cards to review: %{count}", count: to_review)
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

  def send_review_reminder(user_id, opts \\ []) do
    message_id = Keyword.get(opts, :message_id)
    user = Users.get!(user_id)

    count = Cards.count_due(user_id)

    if message_id do
      Telegram.delete_message(user.telegram_id, message_id)
    end

    if count == 0 do
      {:ok, :no_cards_to_review}
    else
      text =
        ngettext(
          "You have <b>%{count}</b> card waiting for review!",
          "You have <b>%{count}</b> cards waiting for review!",
          count,
          count: count
        )

      case Telegram.send_message(user.telegram_id, text,
             reply_markup: %{
               inline_keyboard: [
                 [%{text: "📖 " <> pgettext("button", "Review"), callback_data: "start_review"}],
                 [
                   %{
                     text: "✋ " <> pgettext("button", "Pause reminders"),
                     callback_data: "pause_reminders"
                   }
                 ]
               ]
             }
           ) do
        {:ok, %{"message_id" => new_message_id}} ->
          {:ok, new_message_id}

        _ ->
          {:error, :could_not_send_message}
      end
    end
  end

  def pause_reminders(user) do
    ReviewReminder.pause_reminders(user.id)

    Telegram.send_message(
      user.telegram_id,
      gettext("Reminders paused. Start a /review when you're ready!")
    )
  end

  defp rating_button(card_id, rating, label) do
    %{text: label, callback_data: "rate:#{Jason.encode!(%{"id" => card_id, "r" => rating})}"}
  end
end
