defmodule GiocciRelay.MixProject do
  use Mix.Project

  def project do
    [
      app: :giocci_relay,
      version: "0.3.0-rc1",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GiocciRelay.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dotenvy, "~> 0.9.0"},
      # TODO: need to rebase after releasing zenohex 0.4.0
      # {:zenohex, "~> 0.3.2"}
      {
        :zenohex,
        git: "https://github.com/pojiro/zenohex.git",
        ref: "d385b1b614d8c137882aa07b5e203e1f1574863e"
      },
      {:rustler, ">= 0.0.0", optional: true}
    ]
  end
end
