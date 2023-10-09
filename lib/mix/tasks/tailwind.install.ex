defmodule Mix.Tasks.Tailwind.Install do
  @moduledoc """
  Installs Tailwind executable and assets.

      $ mix tailwind.install
      $ mix tailwind.install --if-missing

  By default, it installs #{Tailwind.latest_version()} but you
  can configure it in your config files, such as:

      config :tailwind, :version, "#{Tailwind.latest_version()}"

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

    * phx-no-feedback - applied when feedback should be hidden from the user
    * phx-click-loading - applied when an event is sent to the server on click
      while the client awaits the server response
    * phx-submit-loading - applied when a form is submitted while the client awaits the server response
    * phx-submit-loading - applied when a form input is changed while the client awaits the server response

  Therefore, you may apply a variant, such as `phx-click-loading:animate-pulse`
  to customize tailwind classes when Phoenix LiveView classes are applied.
  """

  @shortdoc "Installs Tailwind executable and assets"
  @compile {:no_warn_undefined, Mix}

  use Mix.Task

  @impl true
  def run(args) do
    valid_options = [runtime_config: :boolean, if_missing: :boolean, assets: :boolean]

    {opts, base_url} =
      case OptionParser.parse_head!(args, strict: valid_options) do
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

    if opts[:runtime_config], do: Mix.Task.run("app.config")

    if opts[:if_missing] && latest_version?() do
      :ok
    else
      if Keyword.get(opts, :assets, true) do
        File.mkdir_p!("assets/css")
        tailwind_config_path = Path.expand("assets/tailwind.config.js")

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

      if function_exported?(Mix, :ensure_application!, 1) do
        Mix.ensure_application!(:inets)
        Mix.ensure_application!(:ssl)
      end

      Mix.Task.run("loadpaths")
      Tailwind.install(base_url)
    end
  end

  defp latest_version?() do
    version = Tailwind.configured_version()
    match?({:ok, ^version}, Tailwind.bin_version())
  end

  defp prepare_app_css do
    app_css =
      case File.read("assets/css/app.css") do
        {:ok, str} -> str
        {:error, _} -> ""
      end

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
end
