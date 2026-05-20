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
