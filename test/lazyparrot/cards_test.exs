defmodule Lazyparrot.CardsTest do
  use Lazyparrot.DataCase, async: true

  alias Lazyparrot.Cards
  alias Lazyparrot.Users.User

  describe "next_due/1" do
    setup do
      %{user: Repo.insert!(%User{telegram_id: 4242})}
    end

    test "offers the most recently added new card first", %{user: user} do
      {:ok, _added_first} = Cards.create(user, %{front: "eins", back: "one"})
      {:ok, added_last} = Cards.create(user, %{front: "zwei", back: "two"})

      assert Cards.next_due(user.id).id == added_last.id
    end

    test "offers due reviewed cards before new ones", %{user: user} do
      {:ok, _new_card} = Cards.create(user, %{front: "eins", back: "one"})
      {:ok, reviewed} = Cards.create(user, %{front: "zwei", back: "two"})

      reviewed
      |> Ecto.Changeset.change(last_review: DateTime.add(DateTime.utc_now(:second), -1, :hour))
      |> Repo.update!()

      assert Cards.next_due(user.id).id == reviewed.id
    end
  end
end
