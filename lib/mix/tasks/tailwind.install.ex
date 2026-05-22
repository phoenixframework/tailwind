defmodule Mix.Tasks.Tailwind.Install do
  @moduledoc """
  Installs Tailwind executable and assets.

  Usage:

      $ mix tailwind.install TASK_OPTIONS BASE_URL

  Example:

      $ mix tailwind.install
      $ mix tailwind.install --if-missing

  By default, it installs #{Tailwind.latest_version()} but you
  can configure it in your config files, such as:

      config :tailwind, :version, "#{Tailwind.latest_version()}"

  To install the Tailwind binary from a custom URL (e.g. if your platform isn't
  officially supported by Tailwind), you can supply a third party path to the
  binary (beware that we cannot guarantee the compatibility of any third party
  executable):

      $ mix tailwind.install https://people.freebsd.org/~dch/pub/tailwind/$version/tailwindcss-$target

  ## Options

    * `--runtime-config` - load the runtime configuration
      before executing command

    * `--if-missing` - install only if the given version
      does not exist

  """

  @shortdoc "Installs Tailwind executable"
  @compile {:no_warn_undefined, Mix}

  use Mix.Task

  @impl true
  def run(args) do
    {opts, base_url} = parse_arguments(args)

    if opts[:runtime_config] do
      Mix.Task.run("app.config")
    end

    case resolve_versions(opts) do
      [] -> :ok
      versions -> install_versions(base_url, versions)
    end
  end

  defp resolve_versions(opts) do
    for {version, latest?} <- collect_versions(),
        !(opts[:if_missing] && latest?) do
      version
    end
  end

  defp install_versions(base_url, versions) do
    ensure_install_ready()

    if Enum.all?(versions, &(Tailwind.install(base_url, &1) == :ok)) do
      :ok
    else
      :error
    end
  end

  defp ensure_install_ready do
    if function_exported?(Mix, :ensure_application!, 1) do
      Mix.ensure_application!(:inets)
      Mix.ensure_application!(:ssl)
    end

    Mix.Task.run("loadpaths")
  end

  defp parse_arguments(args) do
    case OptionParser.parse_head!(args, strict: schema()) do
      {opts, []} ->
        {opts, Tailwind.default_base_url()}

      {opts, [base_url]} ->
        {opts, base_url}

      {_, _} ->
        Mix.raise("""
        Invalid arguments to tailwind.install, expected one of:

            mix tailwind.install
            mix tailwind.install 'https://github.com/tailwindlabs/tailwindcss/releases/download/v$version/tailwindcss-$target'
            mix tailwind.install --runtime-config
            mix tailwind.install --if-missing
        """)
    end
  end

  defp collect_versions do
    case Tailwind.profiles() do
      [] ->
        [{Tailwind.configured_version(), latest_version?()}]

      profiles ->
        for {profile, _} <- profiles, uniq: true do
          {Tailwind.configured_version(profile), latest_version?(profile)}
        end
    end
  end

  defp latest_version? do
    version = Tailwind.configured_version()
    match?({:ok, ^version}, Tailwind.bin_version())
  end

  defp latest_version?(profile) do
    version = Tailwind.configured_version(profile)
    match?({:ok, ^version}, Tailwind.bin_version(profile))
  end

  defp schema do
    [runtime_config: :boolean, if_missing: :boolean]
  end
end
