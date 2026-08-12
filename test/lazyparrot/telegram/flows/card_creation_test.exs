defmodule Lazyparrot.Telegram.Flows.CardCreationTest do
  use Lazyparrot.BotCase

  alias Lazyparrot.Cards
  alias Lazyparrot.Users

  @telegram_id 4242

  test "cancelling card creation after entering the front" do
    telegram_user(id: @telegram_id)
    |> start_session()
    |> send_message("bonjour")
    |> assert_text("send me the back of the card")
    |> assert_has_button("Cancel")
    |> click_button("Cancel")
    |> assert_text("Card creation cancelled")

    user = Users.get_by_telegram_id!(@telegram_id)
    assert user.current_flow == nil
    assert Cards.count_by_status(user.id) == %{mature: 0, active: 0, new: 0}
  end

  test "escapes HTML-unsafe characters in card text" do
    telegram_user(id: @telegram_id)
    |> start_session()
    |> send_message("<viel> & Spaß")
    |> send_message("a lot > of fun")
    |> assert_text("Card saved!")
    |> assert_text("<b>&lt;viel&gt; &amp; Spaß</b>")
    |> assert_text("a lot &gt; of fun")
  end
end
