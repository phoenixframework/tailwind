defmodule Tailwind.Downloader.GithubRelease do
  @moduledoc """
  Build the Github Release URL.
  """
  @behaviour Tailwind.Downloader

  @impl true
  def get_url(version, target) do
    name = "tailwindcss-#{target}"

    "https://github.com/tailwindlabs/tailwindcss/releases/download/v#{version}/#{name}"
  end
end
