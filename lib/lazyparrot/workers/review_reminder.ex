defmodule Lazyparrot.Workers.ReviewReminder do
  use Oban.Worker,
    unique: [
      period: :infinity,
      states: :scheduled,
      keys: [:user_id]
    ]

  import Ecto.Query, warn: false

  alias Lazyparrot.Repo
  alias Lazyparrot.Telegram.Reviews

  require Logger

  @default_delay 24 * 60 * 60

  def perform(%Oban.Job{args: %{"user_id" => user_id, "message_id" => message_id}}) do
    case Reviews.send_review_reminder(user_id, message_id: message_id) do
      {:ok, :no_cards_to_review} ->
        :ok

      {:ok, new_message_id} ->
        schedule_reminder(user_id, message_id: new_message_id)
        :ok

      {:error, reason} ->
        Logger.error("Failed to send review reminder to user #{user_id}: #{inspect(reason)}")
        :ok
    end
  end

  def schedule_reminder(user_id, opts \\ []) do
    schedule_in = Keyword.get(opts, :schedule_in, @default_delay)

    %{user_id: user_id, message_id: opts[:message_id]}
    |> __MODULE__.new(schedule_in: schedule_in, replace: [:scheduled_at])
    |> Oban.insert!()
  end

  def pause_reminders(user_id) do
    from(j in Oban.Job,
      where: j.state in ["scheduled", "available"],
      where: j.worker == "Lazyparrot.Workers.ReviewReminder",
      where: j.args["user_id"] == ^user_id
    )
    |> Repo.delete_all()

    :ok
  end
end
