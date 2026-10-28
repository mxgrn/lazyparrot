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

  describe "image sides" do
    setup do
      %{user: Repo.insert!(%User{telegram_id: 4242})}
    end

    test "a side needs text or an image", %{user: user} do
      assert {:error, changeset} = Cards.create(user, %{back: "cat"})
      assert %{front: ["can't be blank"]} = errors_on(changeset)

      assert {:ok, _card} = Cards.create(user, %{front_image: "photo_cat", back: "cat"})
    end

    test "get_by_sides/2 matches missing captions and images", %{user: user} do
      {:ok, card} = Cards.create(user, %{front_image: "photo_cat", back: "cat"})

      {:ok, _captioned} =
        Cards.create(user, %{front: "Felis", front_image: "photo_cat", back: "cat"})

      assert Cards.get_by_sides(user.id, %{
               front: nil,
               front_image: "photo_cat",
               back: "cat",
               back_image: nil
             }).id == card.id
    end
  end
end
