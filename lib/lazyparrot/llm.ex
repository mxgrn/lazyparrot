defmodule Lazyparrot.Llm do
  require Logger

  @model Application.compile_env(:lazyparrot, [:llm, :model])

  def translate(text, locale, opts \\ []) do
    context = Keyword.get(opts, :context, "default")
    prompt = translation_prompt(text, locale, context)
    schema = [translation: [type: :string, required: true]]

    case ReqLLM.generate_object(@model, prompt, schema) do
      {:ok, %{object: %{"translation" => translation}}} ->
        {:ok, translation}

      {:ok, response} ->
        Logger.warning("LLM didn't return expected object: #{inspect(response)}")
        {:error, :invalid_response}

      {:error, reason} ->
        Logger.warning("LLM translation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp translation_prompt(text, locale, "button") do
    """
    Translate the following UI button label for a flashcard app into the language with code "#{locale}".
    Use infinitive verb form (not imperative). Keep it short.
    Preserve any %{variable} placeholders exactly as they are.

    Text: #{text}
    """
  end

  defp translation_prompt(text, locale, _context) do
    """
    Translate the following UI text for a spaced-repetition flashcard app into the language with code "#{locale}".
    Keep the tone friendly and concise.
    Preserve any %{variable} placeholders exactly as they are.

    Text: #{text}
    """
  end
end
