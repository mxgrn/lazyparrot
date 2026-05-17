defmodule Lazyparrot.Users do
  alias Lazyparrot.Repo
  alias Lazyparrot.Users.User

  def get!(id), do: Repo.get!(User, id)

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
