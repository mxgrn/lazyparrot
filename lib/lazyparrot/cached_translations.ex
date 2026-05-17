defmodule Lazyparrot.CachedTranslations do
  import Ecto.Query

  alias Lazyparrot.CachedTranslations.CachedTranslation
  alias Lazyparrot.Repo

  def translate!(key, locale, opts \\ []) do
    if locale == "en" do
      key
    else
      context = Keyword.get(opts, :context, "default")
      domain = Keyword.get(opts, :domain, "default")

      case get(key, locale, context: context, domain: domain) do
        %{value: value} ->
          value

        nil ->
          case Lazyparrot.Llm.translate(key, locale, context: context) do
            {:ok, translation} ->
              %CachedTranslation{}
              |> CachedTranslation.changeset(%{
                key: key,
                locale: locale,
                value: translation,
                context: context,
                domain: domain
              })
              |> Repo.insert!(on_conflict: :nothing)

              translation

            {:error, _reason} ->
              key
          end
      end
    end
  end

  defp get(key, locale, opts) do
    context = Keyword.get(opts, :context, "default")
    domain = Keyword.get(opts, :domain, "default")
    key_hash = :crypto.hash(:sha256, key)

    from(t in CachedTranslation,
      where:
        t.key_hash == ^key_hash and
          t.locale == ^locale and
          t.context == ^context and
          t.domain == ^domain,
      select: %{value: t.value}
    )
    |> Repo.one()
  end
end
