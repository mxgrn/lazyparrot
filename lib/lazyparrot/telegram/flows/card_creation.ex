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
    {:ok, _card} = Cards.create(user, %{front: front, back: back_text})

    Users.reset_flow!(user)

    Telegram.send_message(
      user.telegram_id,
      gettext("Card saved!") <> "\n\n<b>#{front}</b>\n#{back_text}"
    )
  end
end
