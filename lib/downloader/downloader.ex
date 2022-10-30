defmodule Tailwind.Downloader do
  @type version :: String.t()
  @type target :: String.t()
  @type url :: String.t()

  @callback get_url(version, target) :: url

  defmacro __using__(_opts) do
    quote do
      require Logger

      # Available targets:
      #  tailwindcss-linux-arm64
      #  tailwindcss-linux-x64
      #  tailwindcss-macos-arm64
      #  tailwindcss-macos-x64
      #  tailwindcss-windows-x64.exe
      def target do
        arch_str = :erlang.system_info(:system_architecture)
        [arch | _] = arch_str |> List.to_string() |> String.split("-")

        case {:os.type(), arch, :erlang.system_info(:wordsize) * 8} do
          {{:win32, _}, _arch, 64} ->
            "windows-x64.exe"

          {{:unix, :darwin}, arch, 64} when arch in ~w(arm aarch64) ->
            "macos-arm64"

          {{:unix, :darwin}, "x86_64", 64} ->
            "macos-x64"

          {{:unix, :linux}, "aarch64", 64} ->
            "linux-arm64"

          {{:unix, _osname}, arch, 64} when arch in ~w(x86_64 amd64) ->
            "linux-x64"

          {_os, _arch, _wordsize} ->
            raise "tailwind is not available for architecture: #{arch_str}"
        end
      end

      def fetch_body!(url) do
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
        cacertfile = CAStore.file_path() |> String.to_charlist()

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

      defp protocol_versions do
        if otp_version() < 25, do: [:"tlsv1.2"], else: [:"tlsv1.2", :"tlsv1.3"]
      end

      defp otp_version do
        :erlang.system_info(:otp_release) |> List.to_integer()
      end
    end
  end
end
