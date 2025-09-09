defmodule TailwindTest do
  use ExUnit.Case, async: true

  @version Tailwind.latest_version()

  setup do
    Application.put_env(:tailwind, :version, @version)
    :ok
  end

  test "--help" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ @version
  end

  test "run on profile" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:another, []) == 0
           end) =~ @version
  end

  test "run on default" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, []) == 0
           end) =~ @version
  end

  test "installs and updates with custom config" do
    Application.put_env(:tailwind, :version, "3.4.17")

    Mix.Task.rerun("tailwind.install", [
      "https://github.com/tailwindlabs/tailwindcss/releases/download/v$version/tailwindcss-$target"
    ])

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ "3.4.17"

    Application.delete_env(:tailwind, :version)

    Mix.Task.rerun("tailwind.install", ["--if-missing"])
    assert File.read!("assets/css/app.css") =~ "tailwind"

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ @version
  end
end
