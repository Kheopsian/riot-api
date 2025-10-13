import Config

config :riot_api,
  hmac_secret: System.get_env("HMAC_SECRET", "super-secret-key")
