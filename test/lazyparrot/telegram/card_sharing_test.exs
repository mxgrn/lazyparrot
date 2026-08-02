defmodule Lazyparrot.Telegram.CardSharingTest do
  use Lazyparrot.BotCase

  alias Lazyparrot.Cards
  alias Lazyparrot.Cards.Card
  alias Lazyparrot.Users
  alias Lazyparrot.Users.User

  @clicker_telegram_id 4242

  describe "claiming a shared card via /start deep link" do
    setup do
      sharer = Repo.insert!(%User{telegram_id: 1111})
      {:ok, shared_card} = Cards.create(sharer, %{front: "la résilience", back: "resilience"})
      %{sharer: sharer, shared_card: shared_card}
    end

    test "copies the card to the clicker and adds it to their queue", %{shared_card: shared_card} do
      telegram_user(id: @clicker_telegram_id)
      |> start_session()
      |> send_message("/start learn_#{shared_card.id}")
      |> assert_text("la résilience")
      |> assert_has_button("Share card")

      clicker = Users.get_by_telegram_id!(@clicker_telegram_id)
      copy = Repo.get_by!(Card, user_id: clicker.id, front: "la résilience")
      assert copy.id != shared_card.id
      assert copy.back == "resilience"

      # due immediately, so it enters the review queue right away
      assert Cards.next_due(clicker.id).id == copy.id
    end

    test "claiming twice does not duplicate the card and credits the sharer once",
         %{sharer: sharer, shared_card: shared_card} do
      session =
        telegram_user(id: @clicker_telegram_id)
        |> start_session()
        |> send_message("/start learn_#{shared_card.id}")

      session
      |> reload_session()
      |> send_message("/start learn_#{shared_card.id}")

      clicker = Users.get_by_telegram_id!(@clicker_telegram_id)
      assert Cards.count(clicker.id) == 1
      assert Repo.get!(User, sharer.id).share_claims_count == 1
    end

    test "claiming your own card does not credit you or duplicate it",
         %{sharer: sharer, shared_card: shared_card} do
      telegram_user(id: sharer.telegram_id)
      |> start_session()
      |> send_message("/start learn_#{shared_card.id}")
      |> assert_text("la résilience")

      assert Cards.count(sharer.id) == 1
      assert Repo.get!(User, sharer.id).share_claims_count == 0
    end

    test "an unusable payload falls back to the welcome message" do
      telegram_user(id: @clicker_telegram_id)
      |> start_session()
      |> send_message("/start learn_999999")
      |> assert_text("You have no flashcards yet")
    end
  end

  describe "share button" do
    test "the review answer offers to share the card" do
      telegram_user(id: @clicker_telegram_id)
      |> start_session()
      |> send_message("guten Tag")
      |> send_message("good day")
      |> assert_has_button("Share card")
      |> send_message("/review")
      |> click_button("Show answer")
      |> assert_has_button("Share card")
    end
  end
end
