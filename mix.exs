defmodule TempProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :riot_api,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        riot_api: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RiotApi.Application, []},
      registered: [RiotApi.Supervisor]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:plug_crypto, "~> 2.1"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
