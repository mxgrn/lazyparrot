defmodule Lazyparrot.Cards do
  import Ecto.Query

  alias Lazyparrot.Cards.Card
  alias Lazyparrot.Repo

  def create(user, attrs) do
    fsrs = ExFsrs.new()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Card{}
    |> Card.changeset(
      Map.merge(attrs, %{
        user_id: user.id,
        state: fsrs.state,
        step: fsrs.step,
        stability: fsrs.stability,
        difficulty: fsrs.difficulty,
        due: now,
        last_review: nil
      })
    )
    |> Repo.insert()
  end

  def next_due(user_id) do
    now = DateTime.utc_now()

    from(c in Card,
      where: c.user_id == ^user_id and c.due <= ^now,
      order_by: [desc: fragment("? IS NOT NULL", c.last_review), asc: c.due],
      limit: 1
    )
    |> Repo.one()
  end

  def count_due(user_id) do
    now = DateTime.utc_now()

    from(c in Card, where: c.user_id == ^user_id and c.due <= ^now)
    |> Repo.aggregate(:count)
  end

  def count(user_id) do
    from(c in Card, where: c.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  def get_for_user(card_id, user_id) do
    from(c in Card, where: c.id == ^card_id and c.user_id == ^user_id)
    |> Repo.one()
  end

  def to_ex_fsrs(%Card{} = card) do
    card
    |> Map.from_struct()
    |> Map.take([:state, :step, :stability, :difficulty, :due, :last_review])
    |> Map.put(:card_id, card.id)
    |> then(&struct!(ExFsrs, &1))
  end

  def update_fsrs!(%Card{} = card, %ExFsrs{} = fsrs_data) do
    card
    |> Card.fsrs_changeset(Map.from_struct(fsrs_data))
    |> Repo.update!()
  end

  def delete!(%Card{} = card) do
    Repo.delete!(card)
  end
end
