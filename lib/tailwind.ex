defmodule Tailwind do
  # https://github.com/tailwindlabs/tailwindcss/releases
  @latest_version "3.2.4"

  @moduledoc """
  Tailwind is an installer and runner for [tailwind](https://tailwindcss.com/).

  ## Profiles

  You can define multiple tailwind profiles. By default, there is a
  profile called `:default` which you can configure its args, current
  directory and environment:

      config :tailwind,
        version: "#{@latest_version}",
        default: [
          args: ~w(
            --config=tailwind.config.js
            --input=css/app.css
            --output=../priv/static/assets/app.css
          ),
          cd: Path.expand("../assets", __DIR__),
        ]

  ## Tailwind configuration

  There are two global configurations for the tailwind application:

    * `:version` - the expected tailwind version

    * `:path` - the path to find the tailwind executable at. By
      default, it is automatically downloaded and placed inside
      the `_build` directory of your current app

  Overriding the `:path` is not recommended, as we will automatically
  download and manage `tailwind` for you. But in case you can't download
  it (for example, GitHub behind a proxy), you may want to
  set the `:path` to a configurable system location.

  For instance, you can install `tailwind` globally with `npm`:

      $ npm install -g tailwindcss

  On Unix, the executable will be at:

      NPM_ROOT/tailwind/node_modules/tailwind-TARGET/bin/tailwind

  On Windows, it will be at:

      NPM_ROOT/tailwind/node_modules/tailwind-windows-(32|64)/tailwind.exe

  Where `NPM_ROOT` is the result of `npm root -g` and `TARGET` is your system
  target architecture.

  Once you find the location of the executable, you can store it in a
  `MIX_TAILWIND_PATH` environment variable, which you can then read in
  your configuration file:

      config :tailwind, path: System.get_env("")

  The first time this package is installed, a default tailwind configuration
  will be placed in a new `assets/tailwind.config.js` file. See
  the [tailwind documentation](https://tailwindcss.com/docs/configuration)
  on configuration options.

  *Note*: The stand-alone Tailwind client bundles first-class tailwind packages
  within the precompiled executable. For third-party Tailwind plugin support,
  the node package must be used. See the
  [tailwind nodejs installation instructions](https://tailwindcss.com/docs/installation)
  if you require third-party plugin support.

  The default tailwind configuration includes Tailwind variants for Phoenix LiveView specific
  lifecycle classes:

    * phx-no-feedback - applied when feedback should be hidden from the user
    * phx-click-loading - applied when an event is sent to the server on click
      while the client awaits the server response
    * phx-submit-loading - applied when a form is submitted while the client awaits the server response
    * phx-submit-loading - applied when a form input is changed while the client awaits the server response

  Therefore, you may apply a variant, such as `phx-click-loading:animate-pulse` to customize tailwind classes
  when Phoenix LiveView classes are applied.
  """

  use Application
  require Logger

  @doc false
  def start(_, _) do
    unless Application.get_env(:tailwind, :version) do
      Logger.warn("""
      tailwind version is not configured. Please set it in your config files:

          config :tailwind, :version, "#{latest_version()}"
      """)
    end

    configured_version = configured_version()

    case bin_version() do
      {:ok, ^configured_version} ->
        :ok

      {:ok, version} ->
        Logger.warn("""
        Outdated tailwind version. Expected #{configured_version}, got #{version}. \
        Please run `mix tailwind.install` or update the version in your config files.\
        """)

      :error ->
        :ok
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end

  @doc false
  # Latest known version at the time of publishing.
  def latest_version, do: @latest_version

  @doc """
  Returns the configured tailwind version.
  """
  def configured_version do
    Application.get_env(:tailwind, :version, latest_version())
  end

  @doc """
  Returns the configuration for the given profile.

  Returns nil if the profile does not exist.
  """
  def config_for!(profile) when is_atom(profile) do
    Application.get_env(:tailwind, profile) ||
      raise ArgumentError, """
      unknown tailwind profile. Make sure the profile is defined in your config/config.exs file, such as:

          config :tailwind,
            version: "#{@latest_version}",
            #{profile}: [
              args: ~w(
                --config=tailwind.config.js
                --input=css/app.css
                --output=../priv/static/assets/app.css
              ),
              cd: Path.expand("../assets", __DIR__)
            ]
      """
  end

  @doc """
  Returns the path to the executable.

  The executable may not be available if it was not yet installed.
  """
  def bin_path do
    name = "tailwind-#{target()}"

    Application.get_env(:tailwind, :path) ||
      if Code.ensure_loaded?(Mix.Project) do
        Path.join(Path.dirname(Mix.Project.build_path()), name)
      else
        Path.expand("_build/#{name}")
      end
  end

  @doc """
  Returns the version of the tailwind executable.

  Returns `{:ok, version_string}` on success or `:error` when the executable
  is not available.
  """
  def bin_version do
    path = bin_path()

    with true <- File.exists?(path),
         {out, 0} <- System.cmd(path, ["--help"]),
         [vsn] <- Regex.run(~r/tailwindcss v([^\s]+)/, out, capture: :all_but_first) do
      {:ok, vsn}
    else
      _ -> :error
    end
  end

  @doc """
  Runs the given command with `args`.

  The given args will be appended to the configured args.
  The task output will be streamed directly to stdio. It
  returns the status of the underlying call.
  """
  def run(profile, extra_args) when is_atom(profile) and is_list(extra_args) do
    config = config_for!(profile)
    args = config[:args] || []

    opts = [
      cd: config[:cd] || File.cwd!(),
      env: config[:env] || %{},
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    ]

    bin_path()
    |> System.cmd(args ++ extra_args, opts)
    |> elem(1)
  end

  @doc """
  Installs, if not available, and then runs `tailwind`.

  Returns the same as `run/2`.
  """
  def install_and_run(profile, args) do
    unless File.exists?(bin_path()) do
      install()
    end

    run(profile, args)
  end

  @doc """
  The default URL to install Tailwind from.
  """
  def default_base_url do
    "https://github.com/tailwindlabs/tailwindcss/releases/download/v$version/tailwindcss-$target"
  end

  @doc """
  Installs tailwind with `configured_version/0`.
  """
  def install(base_url \\ default_base_url()) do
    url = get_url(base_url)
    bin_path = bin_path()
    tailwind_config_path = Path.expand("assets/tailwind.config.js")
    binary = fetch_body!(url)
    File.mkdir_p!(Path.dirname(bin_path))

    # MacOS doesn't recompute code signing information if a binary
    # is overwritten with a new version, so we force creation of a new file
    if File.exists?(bin_path) do
      File.rm!(bin_path)
    end

    File.write!(bin_path, binary, [:binary])
    File.chmod(bin_path, 0o755)

    File.mkdir_p!("assets/css")

    prepare_app_css()
    prepare_app_js()

    unless File.exists?(tailwind_config_path) do
      File.write!(tailwind_config_path, """
      // See the Tailwind configuration guide for advanced usage
      // https://tailwindcss.com/docs/configuration

      let plugin = require('tailwindcss/plugin')

      module.exports = {
        content: [
          './js/**/*.js',
          '../lib/*_web.ex',
          '../lib/*_web/**/*.*ex'
        ],
        theme: {
          extend: {},
        },
        plugins: [
          require('@tailwindcss/forms'),
          plugin(({addVariant}) => addVariant('phx-no-feedback', ['&.phx-no-feedback', '.phx-no-feedback &'])),
          plugin(({addVariant}) => addVariant('phx-click-loading', ['&.phx-click-loading', '.phx-click-loading &'])),
          plugin(({addVariant}) => addVariant('phx-submit-loading', ['&.phx-submit-loading', '.phx-submit-loading &'])),
          plugin(({addVariant}) => addVariant('phx-change-loading', ['&.phx-change-loading', '.phx-change-loading &']))
        ]
      }
      """)
    end
  end

  # Available targets:
  #  tailwindcss-freebsd-arm64
  #  tailwindcss-freebsd-x64
  #  tailwindcss-linux-arm64
  #  tailwindcss-linux-x64
  #  tailwindcss-linux-armv7
  #  tailwindcss-macos-arm64
  #  tailwindcss-macos-x64
  #  tailwindcss-windows-x64.exe
  defp target do
    arch_str = :erlang.system_info(:system_architecture)
    [arch | _] = arch_str |> List.to_string() |> String.split("-")

    case {:os.type(), arch, :erlang.system_info(:wordsize) * 8} do
      {{:win32, _}, _arch, 64} -> "windows-x64.exe"
      {{:unix, :darwin}, arch, 64} when arch in ~w(arm aarch64) -> "macos-arm64"
      {{:unix, :darwin}, "x86_64", 64} -> "macos-x64"
      {{:unix, :freebsd}, "aarch64", 64} -> "freebsd-arm64"
      {{:unix, :freebsd}, "amd64", 64} -> "freebsd-x64"
      {{:unix, :linux}, "aarch64", 64} -> "linux-arm64"
      {{:unix, :linux}, "arm", 32} -> "linux-armv7"
      {{:unix, :linux}, "armv7" <> _, 32} -> "linux-armv7"
      {{:unix, _osname}, arch, 64} when arch in ~w(x86_64 amd64) -> "linux-x64"
      {_os, _arch, _wordsize} -> raise "tailwind is not available for architecture: #{arch_str}"
    end
  end

  defp fetch_body!(url) do
    url = String.to_charlist(url)
    Logger.debug("Downloading tailwind from #{url}")

    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    if proxy = System.get_env("HTTP_PROXY") || System.get_env("http_proxy") do
      Logger.debug("Using HTTP_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)
      :httpc.set_options([{:proxy, {{String.to_charlist(host), port}, []}}])
    end

    if proxy = System.get_env("HTTPS_PROXY") || System.get_env("https_proxy") do
      Logger.debug("Using HTTPS_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)
      :httpc.set_options([{:https_proxy, {{String.to_charlist(host), port}, []}}])
    end

    # https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/inets
    cacertfile = cacertfile() |> String.to_charlist()

    http_options = [
      ssl: [
        verify: :verify_peer,
        cacertfile: cacertfile,
        depth: 2,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ],
        versions: protocol_versions()
      ]
    ]

    options = [body_format: :binary]

    case :httpc.request(:get, {url, []}, http_options, options) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body

      other ->
        raise "couldn't fetch #{url}: #{inspect(other)}"
    end
  end

  defp cacertfile() do
    Application.get_env(:tailwind, :cacerts_path) || CAStore.file_path()
  end

  defp protocol_versions do
    if otp_version() < 25, do: [:"tlsv1.2"], else: [:"tlsv1.2", :"tlsv1.3"]
  end

  defp otp_version do
    :erlang.system_info(:otp_release) |> List.to_integer()
  end

  defp prepare_app_css do
    app_css = app_css()

    unless app_css =~ "tailwind" do
      File.write!("assets/css/app.css", """
      @import "tailwindcss/base";
      @import "tailwindcss/components";
      @import "tailwindcss/utilities";

      #{String.replace(app_css, ~s|@import "./phoenix.css";\n|, "")}\
      """)
    end
  end

  defp prepare_app_js do
    case File.read("assets/js/app.js") do
      {:ok, app_js} ->
        File.write!("assets/js/app.js", String.replace(app_js, ~s|import "../css/app.css"\n|, ""))

      {:error, _} ->
        :ok
    end
  end

  defp app_css do
    case File.read("assets/css/app.css") do
      {:ok, str} -> str
      {:error, _} -> ""
    end
  end

  defp get_url(base_url) do
    base_url
    |> String.replace("$version", configured_version())
    |> String.replace("$target", target())
  end
end
