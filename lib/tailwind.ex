defmodule Tailwind do
  # https://github.com/tailwindlabs/tailwindcss/releases
  @latest_version "4.3.0"

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
            --input=assets/css/app.css
            --output=priv/static/assets/app.css
          ),
          cd: Path.expand("..", __DIR__),
        ]

  It is also possible to override the required tailwind CLI version on
  profile-basis. This is incompatible with the global `:path` setting, since `:path` points to a single executable. Configuring a profile
  with its own `:version` while `:path` is set will raise at boot.

  ## Tailwind configuration

  There are four global configurations for the tailwind application:

    * `:version` - the expected tailwind version

    * `:version_check` - whether to perform the version check or not.
      Useful when you manage the tailwind executable with an external
      tool (eg. npm)

    * `:path` - the path to find the tailwind executable at. By
      default, it is automatically downloaded and placed inside
      the `_build` directory of your current app

    * `:target` - the target architecture for the tailwind executable.
      For example `"linux-x64-musl"`. By default, it is automatically detected
      based on system information.

  Overriding the `:path` is not recommended, as we will automatically
  download and manage `tailwind` for you. But in case you can't download
  it (for example, GitHub behind a proxy), you may want to
  set the `:path` to a configurable system location.

  For instance, you can install `tailwind` and its CLI tool with `npm`.

  From `/assets`:

      $ npm install tailwindcss @tailwindcss/cli

  Then adjust your configuration:

      config :tailwind,
        # check if in sync with /assets/package.json
        version: "#{@latest_version}",
        default: [
          args: ~w(
            --input=assets/css/app.css
            --output=priv/static/assets/app.css
          ),
          cd: Path.expand("..", __DIR__),
        ],
        # skip executable check/download
        version_check: false,
        # path to npm managed CLI tool
        path: Path.expand("../assets/node_modules/.bin/tailwindcss", __DIR__)

  """

  use Application
  require Logger

  @config_keys [:version_check, :version, :target, :path]

  @doc false
  def start(_, _) do
    validate_config!()

    if Application.get_env(:tailwind, :version_check, true) do
      unless Application.get_env(:tailwind, :version) do
        Logger.warning("""
        tailwind version is not configured. Please set it in your config files:

            config :tailwind, :version, "#{latest_version()}"
        """)
      end

      for {profile, config} <- profiles() do
        configured_version = Keyword.get(config, :version, configured_version())

        case bin_version(profile) do
          {:ok, ^configured_version} ->
            :ok

          {:ok, version} ->
            Logger.warning("""
            Outdated tailwind version. Expected #{configured_version}, got #{version}. \
            Please run `mix tailwind.install` or update the version in your config files.\
            """)

          :error ->
            :ok
        end
      end
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end

  @doc false
  # Latest known version at the time of publishing.
  def latest_version, do: @latest_version

  @doc false
  def profiles do
    :tailwind
    |> Application.get_all_env()
    |> Keyword.drop(@config_keys)
    |> Enum.filter(&Keyword.keyword?(elem(&1, 1)))
  end

  @doc """
  Returns the configured tailwind version.
  """
  def configured_version do
    Application.get_env(:tailwind, :version, latest_version())
  end

  @doc """
  Returns the configured tailwind version for a specific profile.

  If the profile does not exist or a version is not explicitly configured,
  falls back to `configured_version/0`.
  """
  def configured_version(profile) when is_atom(profile) do
    :tailwind
    |> Application.get_env(profile, [])
    |> Keyword.get(:version, configured_version())
  end

  @doc """
  Returns the configured tailwind target.

  By default, it is automatically detected based on `configured_version/0`.
  """
  def configured_target do
    target_for_version(configured_version())
  end

  @doc """
  Returns the configured tailwind target for the given `profile`.

  By default, it is automatically detected based on `configured_version/1`.
  """
  def configured_target(profile) when is_atom(profile) do
    profile
    |> configured_version()
    |> target_for_version()
  end

  defp target_for_version(version) when is_binary(version) do
    Application.get_env(:tailwind, :target, system_target(version))
  end

  defp validate_config! do
    if Application.get_env(:tailwind, :path) do
      profiles_with_version =
        for {profile, config} <- profiles(),
            Keyword.has_key?(config, :version),
            do: profile

      if profiles_with_version != [] do
        raise ArgumentError, """
        cannot configure per-profile :version when global :path is set.

        The global :path points to a single tailwind executable, so it is
        incompatible with profiles that require different versions.

        Profile(s) with :version configured: #{inspect(profiles_with_version)}

        Either remove :path from your :tailwind config, or remove :version
        from the offending profile(s).
        """
      end
    end
  end

  @doc """
  Returns the configuration for the given profile.

  Raises if the profile does not exist.
  """
  def config_for!(profile) when is_atom(profile) do
    Application.get_env(:tailwind, profile) ||
      raise ArgumentError, """
      unknown tailwind profile. Make sure the profile is defined in your config/config.exs file, such as:

          config :tailwind,
            version: "#{@latest_version}",
            #{profile}: [
              args: ~w(
                --input=css/app.css
                --output=../priv/static/assets/app.css
              ),
              cd: Path.expand("../assets", __DIR__)
            ]
      """
  end

  @doc """
  Returns the path to the executable for the given `version`.

  The executable may not be available if it was not yet installed.
  """
  def bin_path(version \\ configured_version()) do
    Application.get_env(:tailwind, :path) || default_bin_path(version)
  end

  defp default_bin_path(version) do
    name = "tailwind-#{target_for_version(version)}-#{version}"

    if Code.ensure_loaded?(Mix.Project) do
      Path.join(Path.dirname(Mix.Project.build_path()), name)
    else
      Path.expand("_build/#{name}")
    end
  end

  @doc """
  Returns the version of the executable.

  Returns `{:ok, vsn}` on success or `:error` when the executable
  is not available.
  """
  def bin_version do
    configured_version()
    |> bin_path()
    |> get_version()
  end

  @doc """
  Returns the version of the executable for the given `profile`.

  Returns `{:ok, vsn}` on success or `:error` when the executable
  is not available.
  """
  def bin_version(profile) when is_atom(profile) do
    profile
    |> configured_version()
    |> bin_path()
    |> get_version()
  end

  defp get_version(path) do
    with true <- File.exists?(path),
         {out, 0} <- System.cmd(path, ["--help"], env: %{"NO_COLOR" => "1"}),
         [vsn] <- Regex.run(~r/tailwindcss v([^\s]+)/, out, capture: :all_but_first) do
      {:ok, vsn}
    else
      _ -> :error
    end
  end

  @doc """
  Runs the tailwind CLI for the given `profile` with `args`.

  The given args will be appended to the configured args.
  The task output will be streamed directly to stdio. It
  returns the status of the underlying call.
  """
  def run(profile, extra_args) when is_atom(profile) and is_list(extra_args) do
    config = config_for!(profile)
    args = config[:args] || []

    env =
      config
      |> Keyword.get(:env, %{})
      |> add_env_variable_to_ignore_browserslist_outdated_warning()

    opts = [
      cd: normalize_windows_driver(config[:cd] || File.cwd!()),
      env: normalize_env(env),
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    ]

    profile
    |> configured_version()
    |> bin_path()
    |> System.cmd(args ++ extra_args, opts)
    |> elem(1)
  end

  # Tailwind watcher misbehaves if the driver letter starts in lowercase,
  # even though it is valid on Windows. More information:
  # https://github.com/phoenixframework/tailwind/issues/129
  defp normalize_windows_driver(path) do
    with {:win32, _} <- :os.type(),
         <<letter, ?:, rest::binary>> when letter in ?a..?z <- to_string(path) do
      <<letter - 32, ?:, rest::binary>>
    else
      _ -> path
    end
  end

  defp add_env_variable_to_ignore_browserslist_outdated_warning(env) do
    Enum.into(env, %{"BROWSERSLIST_IGNORE_OLD_DATA" => "1"})
  end

  @doc """
  Installs, if not available, and then runs the tailwind CLI.

  Returns the same as `run/2`.
  """
  def install_and_run(profile, args) when is_atom(profile) do
    version = configured_version(profile)

    unless File.exists?(bin_path(version)) do
      install(default_base_url(), version)
    end

    run(profile, args)
  end

  @doc """
  Returns the default URL to install Tailwind from.
  """
  def default_base_url do
    "https://github.com/tailwindlabs/tailwindcss/releases/download/v$version/tailwindcss-$target"
  end

  @doc """
  Installs tailwind with `configured_version/0`.

  If given, the executable is downloaded from `base_url`,
  otherwise, `default_base_url/0` is used.
  """
  def install(base_url \\ default_base_url()) do
    install(base_url, configured_version())
  end

  @doc false
  def install(base_url, version) do
    validate_config!()

    url = get_url(base_url, version)
    bin_path = bin_path(version)
    binary = fetch_body!(version, url)
    File.mkdir_p!(Path.dirname(bin_path))

    # MacOS doesn't recompute code signing information if a binary
    # is overwritten with a new version, so we force creation of a new file
    if File.exists?(bin_path) do
      File.rm!(bin_path)
    end

    File.write!(bin_path, binary, [:binary])
    File.chmod!(bin_path, 0o755)

    :ok
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
  defp system_target(version) do
    arch_str = :erlang.system_info(:system_architecture)
    target_triple = arch_str |> List.to_string() |> String.split("-")

    {arch, abi} =
      case target_triple do
        [arch, _vendor, _system, abi] -> {arch, abi}
        [arch, _vendor, abi] -> {arch, abi}
        [arch | _] -> {arch, nil}
      end

    case {:os.type(), arch, abi, :erlang.system_info(:wordsize) * 8} do
      {{:win32, _}, _arch, _abi, 64} ->
        "windows-x64.exe"

      {{:unix, :darwin}, arch, _abi, 64} when arch in ~w(arm aarch64) ->
        "macos-arm64"

      {{:unix, :darwin}, "x86_64", _abi, 64} ->
        "macos-x64"

      {{:unix, :freebsd}, "aarch64", _abi, 64} ->
        "freebsd-arm64"

      {{:unix, :freebsd}, arch, _abi, 64} when arch in ~w(x86_64 amd64) ->
        "freebsd-x64"

      {{:unix, :linux}, "aarch64", abi, 64} ->
        "linux-arm64" <> maybe_add_abi_suffix(abi, version)

      {{:unix, :linux}, "arm", _abi, 32} ->
        "linux-armv7"

      {{:unix, :linux}, "armv7" <> _, _abi, 32} ->
        "linux-armv7"

      {{:unix, _osname}, arch, abi, 64} when arch in ~w(x86_64 amd64) ->
        "linux-x64" <> maybe_add_abi_suffix(abi, version)

      {_os, _arch, _abi, _wordsize} ->
        raise "tailwind is not available for architecture: #{arch_str}"
    end
  end

  defp maybe_add_abi_suffix("musl", version) do
    # Tailwind CLI v4+ added explicit musl versions for Linux as
    # tailwind-linux-x64-musl
    # tailwind-linux-arm64-musl
    if Version.match?(version, "~> 4.0") do
      "-musl"
    else
      ""
    end
  end

  defp maybe_add_abi_suffix(_, _), do: ""

  defp fetch_body!(version, url, retry \\ true) when is_binary(url) do
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

    http_options =
      [
        ssl: [
          verify: :verify_peer,
          cacerts: :public_key.cacerts_get(),
          depth: 2,
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ],
          versions: protocol_versions()
        ]
      ]
      |> maybe_add_proxy_auth(scheme)

    options = [body_format: :binary]

    case {retry, :httpc.request(:get, {url, []}, http_options, options)} do
      {_, {:ok, {{_, 200, _}, _headers, body}}} ->
        body

      {_, {:ok, {{_, 404, _}, _headers, _body}}} ->
        raise """
        The tailwind binary couldn't be found at: #{url}

        This could mean that you're trying to install a version that does not support the detected
        target architecture. For example, Tailwind v4+ dropped support for 32-bit ARM.

        You can see the available files for the configured version at:

        https://github.com/tailwindlabs/tailwindcss/releases/tag/v#{version}
        """

      {true, {:error, {:failed_connect, [{:to_address, _}, {inet, _, reason}]}}}
      when inet in [:inet, :inet6] and
             reason in [:ehostunreach, :enetunreach, :eprotonosupport, :nxdomain] ->
        :httpc.set_options(ipfamily: fallback(inet))
        fetch_body!(version, to_string(url), false)

      other ->
        raise """
        Couldn't fetch #{url}: #{inspect(other)}

        This typically means we cannot reach the source or you are behind a proxy.
        You can try again later and, if that does not work, you might:

          1. If behind a proxy, ensure your proxy is configured and that
             your certificates are set via OTP ca certfile overide via SSL configuration.

          2. Manually download the executable from the URL above and
             place it at "#{bin_path(version)}"

          3. Install and use Tailwind from npmJS. See our module documentation
             to learn more: https://hexdocs.pm/tailwind
        """
    end
  end

  defp fallback(:inet), do: :inet6
  defp fallback(:inet6), do: :inet

  defp proxy_for_scheme("http") do
    get_and_sanitize_env_var("HTTP_PROXY") || get_and_sanitize_env_var("http_proxy")
  end

  defp proxy_for_scheme("https") do
    get_and_sanitize_env_var("HTTPS_PROXY") || get_and_sanitize_env_var("https_proxy")
  end

  defp get_and_sanitize_env_var(env_var) do
    case String.trim(System.get_env(env_var, "")) do
      "" -> nil
      trimmed -> trimmed
    end
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

  defp protocol_versions do
    if otp_version() < 25, do: [:"tlsv1.2"], else: [:"tlsv1.2", :"tlsv1.3"]
  end

  defp otp_version do
    :erlang.system_info(:otp_release) |> List.to_integer()
  end

  defp get_url(base_url, version) do
    base_url
    |> String.replace("$version", version)
    |> String.replace("$target", target_for_version(version))
  end

  defp normalize_env(env) do
    Map.new(env, fn
      {key, value} when is_list(value) -> {key, Enum.join(value, path_sep())}
      other -> other
    end)
  end

  defp path_sep do
    case :os.type() do
      {:win32, _} -> ";"
      {:unix, _} -> ":"
    end
  end
end
