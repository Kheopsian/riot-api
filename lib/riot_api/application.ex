defmodule RiotApi.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: RiotApi.Router, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: RiotApi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
