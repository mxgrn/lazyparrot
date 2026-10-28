defmodule Lazyparrot.Telegram.Flows.CardCreation do
  use Gettext, backend: Lazyparrot.LlmGettext

  alias Lazyparrot.Cards
  alias Lazyparrot.Cards.Card
  alias Lazyparrot.Telegram
  alias Lazyparrot.Telegram.CardSharing
  alias Lazyparrot.Users

  @doc """
  Starts creating a card with `front` (see `Lazyparrot.Telegram.Bot` for its shape)
  as the front side, and asks for the back side.
  """
  def start(user, front) do
    Users.update_flow!(user, __MODULE__, %{"front" => front.text, "front_image" => front.image})

    Telegram.send_message(
      user.telegram_id,
      gettext("Got it! Now send me the back of the card."),
      reply_markup: %{
        inline_keyboard: [
          [
            %{
              text: "❌ " <> pgettext("button", "Cancel"),
              callback_data: "ccancel"
            }
          ]
        ]
      }
    )
  end

  def handle_cancel(user, message_id) do
    if user.current_flow == to_string(__MODULE__) do
      Users.reset_flow!(user)
    end

    Telegram.edit_message(user.telegram_id, message_id, gettext("Card creation cancelled."))
  end

  def handle_message(user, back) do
    args = user.current_flow_args

    {:ok, card} =
      Cards.create(user, %{
        front: args["front"],
        front_image: args["front_image"],
        back: back.text,
        back_image: back.image
      })

    Users.reset_flow!(user)

    send_card_saved(user, card)
  end

  def send_card_saved(user, card) do
    Telegram.send_message(
      user.telegram_id,
      card_saved_text(card),
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
        {:ok, reverse} = Cards.create(user, Card.reverse_sides(card))

        Telegram.edit_message(
          user.telegram_id,
          message_id,
          card_saved_text(reverse),
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
          card_saved_text(card),
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
          card_saved_text(card),
          reply_markup: card_saved_markup(card, user.id)
        )
    end
  end

  @doc """
  Plain-text label for a card side: its text, or a 🖼 marker (with the caption,
  if any) for an image. Escape it before putting it into an HTML message.
  """
  def side_label(text, nil), do: text
  def side_label(nil, _image), do: "🖼 " <> gettext("Image")
  def side_label(caption, _image), do: "🖼 " <> caption

  defp card_saved_text(card) do
    front = Telegram.escape(side_label(card.front, card.front_image))
    back = Telegram.escape(side_label(card.back, card.back_image))
    gettext("Card saved!") <> "\n\n<b>#{front}</b>\n#{back}"
  end

  defp card_saved_markup(card, user_id) do
    reverse_row =
      if Cards.reverse_exists?(user_id, card) do
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

    %{
      inline_keyboard: reverse_row ++ [[CardSharing.share_button(card)], [delete_button(card.id)]]
    }
  end

  defp delete_button(card_id) do
    %{
      text: "🗑️ " <> pgettext("button", "Delete"),
      callback_data: "cdel:#{card_id}"
    }
  end
end
