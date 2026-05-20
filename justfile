expose:
  ssh -v -N -R $PORT:localhost:$PORT lb

remote:
  DOCKER_HOST=ssh://app1 docker exec -ti lazyparrot_prod /app/bin/lazyparrot remote

reset_webhook:
  curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook?url=https://lazyparrot.tunnel.mxgrn.com/telegram"
