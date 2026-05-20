defmodule Lazyparrot.Telegram.Flows.CardCreation do
  use Gettext, backend: Lazyparrot.LlmGettext

  alias Lazyparrot.Cards
  alias Lazyparrot.Telegram
  alias Lazyparrot.Users

  def start(user, front_text) do
    Users.update_flow!(user, __MODULE__, %{"front" => front_text})
    Telegram.send_message(user.telegram_id, gettext("Got it! Now send me the back of the card."))
  end

  def handle_message(user, back_text) do
    front = user.current_flow_args["front"]
    {:ok, card} = Cards.create(user, %{front: front, back: back_text})

    Users.reset_flow!(user)

    Telegram.send_message(
      user.telegram_id,
      card_saved_text(front, back_text),
      reply_markup: card_saved_markup(card, user.id)
    )
  end

  def handle_reverse(user, card_id, message_id) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        Telegram.edit_message(
          user.telegram_id,
          message_id,
          gettext("This card no longer exists.")
        )

      card ->
        {:ok, reverse} = Cards.create(user, %{front: card.back, back: card.front})

        Telegram.edit_message(
          user.telegram_id,
          message_id,
          card_saved_text(reverse.front, reverse.back),
          reply_markup: card_saved_markup(reverse, user.id)
        )
    end
  end

  def handle_delete(user, card_id, message_id) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        Telegram.edit_message(
          user.telegram_id,
          message_id,
          gettext("This card was already deleted.")
        )

      card ->
        Telegram.edit_message(
          user.telegram_id,
          message_id,
          card_saved_text(card.front, card.back),
          reply_markup: %{
            inline_keyboard: [
              [
                %{
                  text: "🗑️ " <> pgettext("button", "Yes, delete"),
                  callback_data: "cdel_y:#{card.id}"
                },
                %{
                  text: "❌ " <> pgettext("button", "Cancel"),
                  callback_data: "cdel_n:#{card.id}"
                }
              ]
            ]
          }
        )
    end
  end

  def handle_delete_confirm(user, card_id, message_id) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        Telegram.edit_message(
          user.telegram_id,
          message_id,
          gettext("This card was already deleted.")
        )

      card ->
        Cards.delete!(card)
        Telegram.edit_message(user.telegram_id, message_id, gettext("Card deleted."))
    end
  end

  def handle_delete_cancel(user, card_id, message_id) do
    case Cards.get_for_user(card_id, user.id) do
      nil ->
        Telegram.edit_message(
          user.telegram_id,
          message_id,
          gettext("This card was already deleted.")
        )

      card ->
        Telegram.edit_message(
          user.telegram_id,
          message_id,
          card_saved_text(card.front, card.back),
          reply_markup: card_saved_markup(card, user.id)
        )
    end
  end

  defp card_saved_text(front, back) do
    gettext("Card saved!") <> "\n\n<b>#{front}</b>\n#{back}"
  end

  defp card_saved_markup(card, user_id) do
    reverse_row =
      if Cards.reverse_exists?(user_id, card.front, card.back) do
        []
      else
        [
          [
            %{
              text: "🔄 " <> pgettext("button", "Add reverse card"),
              callback_data: "crev:#{card.id}"
            }
          ]
        ]
      end

    %{inline_keyboard: reverse_row ++ [[delete_button(card.id)]]}
  end

  defp delete_button(card_id) do
    %{
      text: "🗑️ " <> pgettext("button", "Delete"),
      callback_data: "cdel:#{card_id}"
    }
  end
end
