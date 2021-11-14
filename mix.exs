defmodule DataSchema.MixProject do
  use Mix.Project

  def project do
    [
      app: :data_schema,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      # This is added just so we can test the idea of an XML schema.
      {:sweet_xml, ">= 0.0.0", only: [:dev, :test]}
    ]
  end
end