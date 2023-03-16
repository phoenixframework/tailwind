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

    * `:cacerts_path` - the directory to find certificates for
      https connections

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

      config :tailwind, path: System.get_env("MIX_TAILWIND_PATH")

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
    binary = fetch_body!(url)
    File.mkdir_p!(Path.dirname(bin_path))

    # MacOS doesn't recompute code signing information if a binary
    # is overwritten with a new version, so we force creation of a new file
    if File.exists?(bin_path) do
      File.rm!(bin_path)
    end

    File.write!(bin_path, binary, [:binary])
    File.chmod(bin_path, 0o755)
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
    scheme = URI.parse(url).scheme
    url = String.to_charlist(url)
    Logger.debug("Downloading tailwind from #{url}")

    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    if proxy = proxy_for_scheme(scheme) do
      %{host: host, port: port} = URI.parse(proxy)
      Logger.debug("Using #{String.upcase(scheme)}_PROXY: #{proxy}")
      set_option = if "https" == scheme, do: :https_proxy, else: :proxy
      :httpc.set_options([{set_option, {{String.to_charlist(host), port}, []}}])
    end

    # https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/inets
    cacertfile = cacertfile() |> String.to_charlist()

    http_options =
      [
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
      |> maybe_add_proxy_auth(scheme)

    options = [body_format: :binary]

    case :httpc.request(:get, {url, []}, http_options, options) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body

      other ->
        raise """
        Couldn't fetch #{url}: #{inspect(other)}

        This typically means we cannot reach the source or you are behind a proxy.
        You can try again later and, if that does not work, you might:

          1. If behind a proxy, ensure your proxy is configured and that
             your certificates are set via the cacerts_path configuration

          2. Manually download the executable from the URL above and
             place it inside "_build/tailwind-#{target()}"

          3. Install and use Tailwind from npmJS. See our module documentation
             to learn more: https://hexdocs.pm/tailwind
        """
    end
  end

  defp proxy_for_scheme("http") do
    System.get_env("HTTP_PROXY") || System.get_env("http_proxy")
  end

  defp proxy_for_scheme("https") do
    System.get_env("HTTPS_PROXY") || System.get_env("https_proxy")
  end

  defp maybe_add_proxy_auth(http_options, scheme) do
    case proxy_auth(scheme) do
      nil -> http_options
      auth -> [{:proxy_auth, auth} | http_options]
    end
  end

  defp proxy_auth(scheme) do
    with proxy when is_binary(proxy) <- proxy_for_scheme(scheme),
         %{userinfo: userinfo} when is_binary(userinfo) <- URI.parse(proxy),
         [username, password] <- String.split(userinfo, ":") do
      {String.to_charlist(username), String.to_charlist(password)}
    else
      _ -> nil
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

  defp get_url(base_url) do
    base_url
    |> String.replace("$version", configured_version())
    |> String.replace("$target", target())
  end
end
