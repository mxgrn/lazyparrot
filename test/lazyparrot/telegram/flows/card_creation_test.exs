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

  test "creating a card with a captioned image front and a text back" do
    telegram_user(id: @telegram_id)
    |> start_session()
    |> send_photo("photo_cat", caption: "Felis catus")
    |> assert_text("send me the back of the card")
    |> send_message("cat")
    |> assert_text("<b>🖼 Felis catus</b>\ncat")

    user = Users.get_by_telegram_id!(@telegram_id)
    card = Cards.next_due(user.id)
    assert card.front_image == "photo_cat"
    assert card.front == "Felis catus"
    assert card.back_image == nil
  end

  test "an image without a caption can be the back of a card" do
    telegram_user(id: @telegram_id)
    |> start_session()
    |> send_message("cat")
    |> send_photo("photo_cat")
    |> assert_text("<b>cat</b>\n🖼 Image")
    |> click_button("Add reverse card")
    |> assert_text("<b>🖼 Image</b>\ncat")
    |> refute_has_button("Add reverse card")
  end
end
