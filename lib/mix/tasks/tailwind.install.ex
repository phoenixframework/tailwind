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

      * `--no-assets` - does not install Tailwind assets

  ## Assets

  Whenever Tailwind is installed, a default tailwind configuration
  will be placed in a new `assets/tailwind.config.js` file. See
  the [tailwind documentation](https://tailwindcss.com/docs/configuration)
  on configuration options.

  The default tailwind configuration includes Tailwind variants for Phoenix
  LiveView specific lifecycle classes:

    * phx-click-loading - applied when an event is sent to the server on click
      while the client awaits the server response
    * phx-submit-loading - applied when a form is submitted while the client awaits the server response
    * phx-change-loading - applied when a form input is changed while the client awaits the server response

  Therefore, you may apply a variant, such as `phx-click-loading:animate-pulse`
  to customize tailwind classes when Phoenix LiveView classes are applied.
  """

  @shortdoc "Installs Tailwind executable and assets"
  @compile {:no_warn_undefined, Mix}

  use Mix.Task

  @impl true
  def run(args) do
    if args |> try_install() |> was_successful?() do
      :ok
    else
      :error
    end
  end

  defp try_install(args) do
    {opts, base_url} = parse_arguments(args)

    if opts[:runtime_config], do: Mix.Task.run("app.config")

    for {version, latest?} <- collect_versions() do
      if opts[:if_missing] && latest? do
        :ok
      else
        if Keyword.get(opts, :assets, true) do
          File.mkdir_p!("assets/css")

          prepare_app_css()
          prepare_app_js()
        end

        if function_exported?(Mix, :ensure_application!, 1) do
          Mix.ensure_application!(:inets)
          Mix.ensure_application!(:ssl)
        end

        Mix.Task.run("loadpaths")
        Tailwind.install(base_url, version)
      end
    end
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
    for {profile, _} <- Tailwind.profiles(), uniq: true do
      {Tailwind.configured_version(profile), latest_version?(profile)}
    end
  end

  defp was_successful?(results) do
    Enum.all?(results, &(&1 == :ok))
  end

  defp latest_version?(profile) do
    version = Tailwind.configured_version(profile)
    match?({:ok, ^version}, Tailwind.bin_version(profile))
  end

  defp prepare_app_css do
    app_css =
      case File.read("assets/css/app.css") do
        {:ok, str} -> str
        {:error, _} -> ""
      end

    unless app_css =~ "tailwind" do
      File.write!("assets/css/app.css", """
      @import "tailwindcss";
      @plugin "@tailwindcss/forms";
      @variant phx-click-loading ([".phx-click-loading&", ".phx-click-loading &"]);
      @variant phx-submit-loading ([".phx-submit-loading&", ".phx-submit-loading &"]);
      @variant phx-change-loading ([".phx-change-loading&", ".phx-change-loading &"]);

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

  defp schema do
    [runtime_config: :boolean, if_missing: :boolean, assets: :boolean]
  end
end
