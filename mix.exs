defmodule OpencensusElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :opencensus_elixir,
      version: "0.4.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      description: description(),
      package: package(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        credo: :test,
        docs: :docs,
        "inchci.add": :docs,
        "inch.report": :docs,
        "test.watch": :test
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
      {:opencensus, "~> 0.9"},

      # Documentation
      {:ex_doc, ">= 0.0.0", only: [:docs]},
      {:inch_ex, "~> 1.0", only: [:docs]},

      # Testing
      {:credo, "~> 1.1.0", only: [:test]},
      {:dialyxir, ">= 0.0.0", runtime: false, only: [:dev, :test]},
      {:excoveralls, "~> 0.10.3", only: [:test]},
      {:junit_formatter, ">= 0.0.0", only: [:test]},
      {:mix_test_watch, "~> 0.8", runtime: false, only: [:test]},
      {:telemetry, "~> 0.4 or ~> 1.0"}
    ]
  end

  defp dialyzer() do
    [
      ignore_warnings: "dialyzer.ignore-warnings",
      list_unused_filters: true,
      plt_add_apps: [],
      plt_add_deps: [:app_tree]
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end

  defp description() do
    "Elixir library for OpenCensus tracing"
  end

  defp package() do
    [
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/opencensus-beam/opencensus_elixir",
        "OpenCensus" => "https://opencensus.io",
        "OpenCensus Erlang" => "https://github.com/census-instrumentation/opencensus-erlang",
        "OpenCensus BEAM" => "https://github.com/opencensus-beam"
      }
    ]
  end
end
