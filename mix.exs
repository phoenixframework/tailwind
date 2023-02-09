defmodule Tailwind.MixProject do
  use Mix.Project

  @version "0.1.10"
  @source_url "https://github.com/phoenixframework/tailwind"

  def project do
    [
      app: :tailwind,
      version: @version,
      elixir: "~> 1.10",
      deps: deps(),
      description: "Mix tasks for installing and invoking tailwind",
      package: [
        links: %{
          "GitHub" => @source_url,
          "tailwind" => "https://tailwindcss.com"
        },
        licenses: ["MIT"]
      ],
      docs: [
        main: "Tailwind",
        source_url: @source_url,
        source_ref: "v#{@version}",
        extras: ["CHANGELOG.md"]
      ],
      aliases: [test: ["tailwind.install --if-missing", "test"]]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {Tailwind, []},
      env: [default: []]
    ]
  end

  defp deps do
    [
      {:castore, ">= 0.0.0"},
      {:ex_doc, ">= 0.0.0", only: :docs}
    ]
  end
end
