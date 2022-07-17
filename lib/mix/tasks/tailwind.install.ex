defmodule Mix.Tasks.Tailwind.Install do
  @moduledoc """
  Installs tailwind under `_build`.

  ```bash
  $ mix tailwind.install
  $ mix tailwind.install --if-missing
  ```

  By default, it installs #{Tailwind.latest_version()} but you
  can configure it in your config files, such as:

      config :tailwind, :version, "#{Tailwind.latest_version()}"

  ## Options

      * `--runtime-config` - load the runtime configuration
        before executing command

      * `--if-missing` - install only if the given version
        does not exist
  """

  @shortdoc "Installs tailwind under _build"
  use Mix.Task

  @impl true
  def run(args) do
    valid_options = [runtime_config: :boolean, if_missing: :boolean, skip_prepare: :boolean]

    case OptionParser.parse_head(args, strict: valid_options) do
      {opts, []} ->
        if opts[:runtime_config], do: Mix.Task.run("app.config")

        if opts[:if_missing] && latest_version?() do
          :ok
        else
          opts
          |> Keyword.take([:skip_prepare])
          |> Tailwind.install()
        end

      {_, _, _} ->
        Mix.raise("""
        Invalid arguments to tailwind.install

        usage: mix tailwind.install [--runtime-config] [--if-missing] [--skip-prepare]
          --runtime-config: Tells the task runner to load the runtime mix config before installing
          --if-missing: Detect if tailwind is installed first, then abort
          --skip-prepare: Do not automatically modify assets/js/app.js or assets/css/app.css for tailwind
        """)
    end
  end

  defp latest_version?() do
    version = Tailwind.configured_version()
    match?({:ok, ^version}, Tailwind.bin_version())
  end
end
