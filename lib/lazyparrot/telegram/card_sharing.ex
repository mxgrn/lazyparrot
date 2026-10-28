defmodule Lazyparrot.Telegram.CardSharing do
  @moduledoc """
  Sharing cards between users via `learn_<card_id>` deep links.

  Covers both ends of the feature: minting share links (the Share button on a
  card) and claiming them — copying the card to whoever opened the link and
  crediting the sharer.
  """
  use Gettext, backend: Lazyparrot.LlmGettext

  alias Lazyparrot.Cards
  alias Lazyparrot.Cards.Card
  alias Lazyparrot.Telegram.Flows.CardCreation
  alias Lazyparrot.Users

  require Logger

  @doc """
  The deep link that claims `card` for whoever opens it (handled by `claim/2`).
  """
  def deep_link(card) do
    bot_username = Application.get_env(:lazyparrot, :telegram_bot)[:username]
    "https://t.me/#{bot_username}?start=learn_#{card.id}"
  end

  @doc """
  Opens Telegram's native "share to a chat" picker, prefilled with a card-like
  teaser and the card's claim deep link.
  """
  def share_button(card) do
    # Telegram renders the shared link first, then this text — the leading blank
    # line keeps the teaser from butting up against the link, and the call to
    # action points back up at it. Deliberately minimal: the full card follows
    # once the recipient claims it.
    front = CardCreation.side_label(card.front, card.front_image)
    back = CardCreation.side_label(card.back, card.back_image)
    text = "\n#{front} — #{back}\n\n⬆️ " <> gettext("Follow the link to learn this")

    share_url =
      "https://t.me/share/url?url=#{share_encode(deep_link(card))}&text=#{share_encode(text)}"

    %{text: "🔗 " <> pgettext("button", "Share card"), url: share_url}
  end

  @doc """
  Claims a shared card (via the `learn_<card_id>` deep-link payload) for the user
  who tapped it: copies the card to them, due immediately, and shows it in their
  private chat. Returns `{:error, :not_found}` if the payload is unusable.
  """
  def claim(clicker, card_id) do
    with {id, ""} <- Integer.parse(card_id),
         card when not is_nil(card) <- Cards.get(id) do
      copy = find_or_copy(clicker, card)
      CardCreation.send_card_saved(clicker, copy)
      {:ok, copy}
    else
      failed ->
        Logger.warning(
          "[card_sharing] claim failed for card_id=#{inspect(card_id)}: #{inspect(failed)}"
        )

        {:error, :not_found}
    end
  end

  # Credit the sharer only when the card actually enters the claimer's collection,
  # so double-clicks and self-claims don't inflate the count.
  defp find_or_copy(clicker, card) do
    # Telegram file_ids work in any chat with this bot, so images are shared by id
    case Cards.get_by_sides(clicker.id, Card.sides(card)) do
      nil ->
        {:ok, copy} = Cards.create(clicker, Card.sides(card))
        if card.user_id != clicker.id, do: Users.increment_share_claims_count(card.user_id)
        copy

      existing ->
        existing
    end
  end

  # RFC 3986 encoding (spaces as %20, matching Telegram's documented rawurlencode)
  # so multi-word card text doesn't come out with "+" instead of spaces.
  defp share_encode(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
