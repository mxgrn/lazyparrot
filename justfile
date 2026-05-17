expose:
  ssh -v -N -R $PORT:localhost:$PORT lb

reset_webhook:
  curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook?url=https://lazyparrot.tunnel.mxgrn.com/telegram"
