defmodule ZXCVBN.MixProject do
  use Mix.Project

  @github_link "https://github.com/techgaun/zxcvbn-elixir"

  def project do
    [
      app: :zxcvbn,
      version: "0.1.3",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      build_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

      # coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # docs
      name: "ZXCVBN",
      description: "Elixir implementation of zxcvbn",
      source_url: @github_link,
      homepage_url: @github_link,
      docs: [
        main: "ZXCVBN",
        extras: ["README.md"]
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
      {:ex_doc, "~> 0.20", only: :dev, runtime: false},
      {:benchee, "~> 0.13", only: :dev},
      {:benchee_html, "~> 0.3", only: :dev},
      {:excoveralls, "~> 0.10.6", only: :test},
      {:stream_data, "~> 0.1", only: :test},
      {:jason, "~> 1.1", only: [:dev, :test]},
      {:gettext, "~> 0.18.2"}
    ]
  end

  defp package do
    [
      name: "zxcvbn",
      maintainers: [
        "Samar Acharya"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @github_link},
      files: ~w(lib priv CHANGELOG.md README.md LICENSE mix.exs .formatter.exs)
    ]
  end
end
