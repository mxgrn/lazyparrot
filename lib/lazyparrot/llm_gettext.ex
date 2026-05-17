defmodule Lazyparrot.LlmGettext do
  use Gettext.Backend, otp_app: :lazyparrot

  alias Gettext.Interpolation.Default
  alias Lazyparrot.CachedTranslations

  def handle_missing_translation(locale, domain, context, msgid, bindings) do
    context = context || "default"
    domain = domain || "default"

    {:ok, _translation} =
      CachedTranslations.translate!(msgid, locale, context: context, domain: domain)
      |> Default.runtime_interpolate(bindings)
  end
end
