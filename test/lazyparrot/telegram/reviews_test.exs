defmodule Lazyparrot.Telegram.ReviewsTest do
  use Lazyparrot.BotCase

  alias Lazyparrot.Cards
  alias Lazyparrot.Users.User

  @telegram_id 4242

  setup do
    %{user: Repo.insert!(%User{telegram_id: @telegram_id})}
  end

  test "an image front is edited in place, and a text card after it replaces the photo",
       %{user: user} do
    {:ok, _text_card} = Cards.create(user, %{front: "dog", back: "Hund"})

    {:ok, _image_card} =
      Cards.create(user, %{front: "Felis", front_image: "photo_cat", back: "cat"})

    telegram_user(id: @telegram_id)
    |> start_session()
    |> send_message("/review")
    |> assert_photo("photo_cat")
    |> assert_caption("<b>Felis</b>")
    |> click_button("Show answer")
    |> assert_method("editMessageMedia")
    |> assert_photo("photo_cat")
    |> assert_caption("<b>Felis</b>\n\ncat")
    |> click_button("Fine")
    |> assert_method("sendMessage")
    |> assert_text("<b>dog</b>")
  end

  test "an image back replaces the text question with a photo", %{user: user} do
    {:ok, _card} = Cards.create(user, %{front: "cat", back_image: "photo_cat"})

    session =
      telegram_user(id: @telegram_id)
      |> start_session()
      |> send_message("/review")
      |> assert_text("<b>cat</b>")
      |> click_button("Show answer")
      |> assert_photo("photo_cat")
      |> assert_caption("<b>cat</b>\n\n💁")

    assert [%{method: "deleteMessage"}, %{method: "sendPhoto"}] = Enum.take(session.updates, -2)
  end

  test "shows the answer as text when the caption would be too long", %{user: user} do
    long_back = String.duplicate("a", 1100)
    {:ok, _card} = Cards.create(user, %{front_image: "photo_cat", back: long_back})

    telegram_user(id: @telegram_id)
    |> start_session()
    |> send_message("/review")
    |> click_button("Show answer")
    |> assert_method("sendMessage")
    |> assert_text("<b>🖼 Image</b>\n\n#{long_back}")
  end
end
