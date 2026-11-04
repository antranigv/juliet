defmodule Juliet.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :juliet,
      name: "Juliet",
      version: @version,
      elixir: "~> 1.17",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssl, :crypto, :public_key],
      mod: {Juliet, []}
    ]
  end

  defp description do
    "An XMPP Client for Elixir"
  end

  defp deps do
    [
      {:connection, "~> 1.0"},
      {:saxy, "~> 1.5"},

      # Docs deps
      {:ex_doc, "~> 0.18", only: :dev}
    ]
  end

  defp docs do
    [extras: docs_extras(), main: "readme", source_url: "https://github.com/antranigv/juliet"]
  end

  defp docs_extras do
    ["README.md", "CHANGELOG.md"]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Antranig Vartanian"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/antranigv/juliet"}
    ]
  end
end
