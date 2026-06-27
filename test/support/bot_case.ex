defmodule Lazyparrot.BotCase do
  use ExUnit.CaseTemplate

  alias Gramex.Testing.Sessions.User

  using do
    quote do
      use Gramex.Testing.BotCase

      import Lazyparrot.BotCase
      import Phoenix.ConnTest

      alias Lazyparrot.Repo
    end
  end

  setup tags do
    Lazyparrot.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Builds a Telegram user for starting a session. The matching database user is
  created on the fly by the webhook plugs on the first incoming update.
  """
  def telegram_user(opts \\ []) do
    User.new(Keyword.put_new(opts, :language_code, "en"))
  end
end
