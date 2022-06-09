# Tailwind

[![CI](https://github.com/phoenixframework/tailwind/actions/workflows/main.yml/badge.svg)](https://github.com/phoenixframework/tailwind/actions/workflows/main.yml)

Mix tasks for installing and invoking [tailwindcss](https://tailwindcss.com) via the
stand-alone [tailwindcss cli](https://github.com/tailwindlabs/tailwindcss/tree/master/standalone-cli)

## Installation

If you are going to build assets in production, then you add
`tailwind` as dependency on all environments but only start it
in dev:

```elixir
def deps do
  [
    {:tailwind, "~> 0.1.6", runtime: Mix.env() == :dev}
  ]
end
```

However, if your assets are precompiled during development,
then it only needs to be a dev dependency:

```elixir
def deps do
  [
    {:tailwind, "~> 0.1.6", only: :dev}
  ]
end
```

Once installed, change your `config/config.exs` to pick your
tailwind version of choice:

```elixir
config :tailwind, version: "3.1.0"
```

Now you can install tailwind by running:

```bash
$ mix tailwind.install
```

And invoke tailwind with:

```bash
$ mix tailwind default
```

The executable is kept at `_build/tailwind-TARGET`.
Where `TARGET` is your system target architecture.

## Profiles

The first argument to `tailwind` is the execution profile.
You can define multiple execution profiles with the current
directory, the OS environment, and default arguments to the
`tailwind` task:

```elixir
config :tailwind,
  version: "3.1.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]
```

When `mix tailwind default` is invoked, the task arguments will be appended
to the ones configured above. Note profiles must be configured in your
`config/config.exs`, as `tailwind` runs without starting your application
(and therefore it won't pick settings in `config/runtime.exs`).

## Adding to Phoenix

To add `tailwind` to an application using Phoenix, you will need Phoenix v1.6+
and the following four steps.

First add it as a dependency in your `mix.exs`:

```elixir
def deps do
  [
    {:phoenix, "~> 1.6"},
    {:tailwind, "~> 0.1.6", runtime: Mix.env() == :dev}
  ]
end
```

Now let's change `config/config.exs` to tell `tailwind` to use
configuration in `assets/tailwind.config.js` for building our css
bundle into `priv/static/assets`. We'll also give it our `assets/css/app.css`
as our css entry point:

```elixir
config :tailwind,
  version: "3.1.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]
```

> Make sure the "assets" directory from priv/static is listed in the
> :only option for Plug.Static in your lib/my_app_web/endpoint.ex

If your Phoenix application is using an umbrella structure, you should specify
the web application's asset directory in the configuration:

```elixir
config :tailwind,
  version: "3.1.0",
  default: [
    args: ...,
    cd: Path.expand("../apps/<folder_ending_with_web>/assets", __DIR__)
  ]
```

For development, we want to enable watch mode. So find the `watchers`
configuration in your `config/dev.exs` and add:

```elixir
  tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
```

Note we are enabling the file system watcher.

Check you have correctly removed the `import "../css/app.css"` line
in your `assets/js/app.js`.

Finally, back in your `mix.exs`, make sure you have a `assets.deploy`
alias for deployments, which will also use the `--minify` option:

```elixir
"assets.deploy": ["tailwind default --minify", ..., "phx.digest"]
```

## Tailwind Configuration

The first time this package is installed, a default tailwind configuration
will be placed in a new `assets/tailwind.config.js` file. See
the [tailwind documentation](https://tailwindcss.com/docs/configuration)
on configuration options.

_Note_: The stand-alone Tailwind client bundles first-class tailwind packages
within the precompiled executable. For third-party Tailwind plugin support,
the node package must be used. See the [tailwind nodejs installation instructions](https://tailwindcss.com/docs/installation) if you require third-party plugin support.

## License

Copyright (c) 2022 Chris McCord.
Copyright (c) 2021 Wojtek Mach, José Valim.

tailwind source code is licensed under the [MIT License](LICENSE.md).
