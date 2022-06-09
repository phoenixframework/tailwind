defmodule Tailwind.MixProject do
  use Mix.Project

  @version "0.1.6"
  @source_url "https://github.com/phoenixframework/tailwind"

  def project do
    [
      app: :tailwind,
      version: @version,
      elixir: "~> 1.10",
      otp: ">= 22.0",
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
      xref: [
        exclude: [:httpc, :public_key]
      ],
      aliases: [test: ["tailwind.install --if-missing", "test"]]
    ]
  end

  def application do
    [
      # inets/ssl may be used by Mix tasks but we should not impose them.
      extra_applications: [:logger],
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
