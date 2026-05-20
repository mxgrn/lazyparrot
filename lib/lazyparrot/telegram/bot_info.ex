defmodule Lazyparrot.Telegram.BotInfo do
  use Gettext, backend: Lazyparrot.LlmGettext

  alias Lazyparrot.Telegram

  @short_description "AI-powered flashcards with smart repetition — learn faster, forget less!"

  @description """
  #{@short_description}

  Send me a word or phrase you'd like to learn, and I'll create a flashcard for you!
  Then, I'll help you review your flashcards with smart repetitions to maximize retention.
  """

  @commands """
  /review - Review flashcards
  /stats - Your flashcard stats
  /help - Show help
  """

  defmacro commands, do: @commands

  def command_list do
    @commands
    |> gettext()
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn line ->
      ["/" <> command, description] = String.split(line, " - ", parts: 2)
      %{command: command, description: description}
    end)
  end

  def update_bot_info(language_code) do
    update_descriptions(language_code)
    update_bot_commands(language_code)
  end

  def update_descriptions(language_code) do
    Gettext.put_locale(language_code)

    Telegram.request("setMyShortDescription", %{
      short_description: gettext(@short_description),
      language_code: language_code
    })

    Telegram.request("setMyDescription", %{
      description: gettext(@description),
      language_code: language_code
    })
  end

  def update_bot_commands(language_code) do
    Gettext.put_locale(language_code)

    Telegram.request("setMyCommands", %{
      commands: command_list(),
      language_code: language_code
    })
  end

  def reset_bot_info(language_code) do
    Telegram.request("setMyShortDescription", %{language_code: language_code})
    Telegram.request("setMyDescription", %{language_code: language_code})
    Telegram.request("deleteMyCommands", %{language_code: language_code})
  end
end
