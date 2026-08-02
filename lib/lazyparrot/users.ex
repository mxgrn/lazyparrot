defmodule Lazyparrot.Users do
  import Ecto.Query, warn: false

  alias Lazyparrot.Repo
  alias Lazyparrot.Users.User

  def get!(id), do: Repo.get!(User, id)

  def distinct_language_codes do
    from(u in User,
      distinct: true,
      select: u.telegram_language_code,
      where: not is_nil(u.telegram_language_code)
    )
    |> Repo.all()
  end

  def get_by_telegram_id!(telegram_id) do
    Repo.get_by!(User, telegram_id: telegram_id)
  end

  def increment_share_claims_count(user_id) do
    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(inc: [share_claims_count: 1])
  end

  def update_flow!(user, module, args) do
    user
    |> User.changeset(%{
      current_flow: if(module, do: to_string(module)),
      current_flow_args: args || %{}
    })
    |> Repo.update!()
  end

  def reset_flow!(user) do
    update_flow!(user, nil, %{})
  end
end
