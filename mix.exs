defmodule ZXCVBN.MixProject do
  use Mix.Project

  def project do
    [
      app: :zxcvbn,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],

      # docs
      name: "ZXCVBN",
      source_url: "https://github.com/techgaun/zxcvbn-elixir",
      homepage_url: "https://github.com/techgaun/zxcvbn-elixir",
      docs: [
        main: "ZXCVBN",
        extras: ["readme.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10.6", only: :test},
      {:stream_data, "~> 0.1", only: :test}
    ]
  end
end
