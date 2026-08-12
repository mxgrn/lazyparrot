defmodule Lazyparrot.TelegramTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Lazyparrot.Telegram

  defmodule StubAdapter do
    def request(_token, _method, _params, _opts), do: Process.get(:telegram_stub_response)
  end

  setup do
    original = Application.get_env(:gramex, :adapter)
    Application.put_env(:gramex, :adapter, StubAdapter)
    on_exit(fn -> Application.put_env(:gramex, :adapter, original) end)
    :ok
  end

  test "logs invalid_request responses and normalizes them to :error" do
    Process.put(:telegram_stub_response, {:invalid_request, "Bad Request: can't parse entities"})

    log =
      capture_log(fn ->
        assert Telegram.send_message(123, "<oops>") ==
                 {:error, "Bad Request: can't parse entities"}
      end)

    assert log =~ "[error]"
    assert log =~ "sendMessage"
    assert log =~ "chat_id: 123"
    assert log =~ "can't parse entities"
  end

  test "logs error responses" do
    Process.put(:telegram_stub_response, {:error, "Internal Server Error"})

    log =
      capture_log(fn ->
        assert Telegram.send_message(123, "hi") == {:error, "Internal Server Error"}
      end)

    assert log =~ "[error]"
    assert log =~ "Internal Server Error"
  end

  test "passes blocked responses through without logging an error" do
    Process.put(:telegram_stub_response, {:blocked, "Forbidden: bot was blocked by the user"})

    log =
      capture_log(fn ->
        assert Telegram.send_message(123, "hi") ==
                 {:blocked, "Forbidden: bot was blocked by the user"}
      end)

    refute log =~ "[error]"
  end

  test "passes successful responses through untouched" do
    Process.put(:telegram_stub_response, {:ok, %{"message_id" => 1}})

    assert Telegram.send_message(123, "hi") == {:ok, %{"message_id" => 1}}
  end

  test "escape/1 escapes HTML special characters without double-escaping" do
    assert Telegram.escape("a < b & c > d") == "a &lt; b &amp; c &gt; d"
  end
end
