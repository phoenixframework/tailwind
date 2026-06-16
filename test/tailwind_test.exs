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

  test "raises when :path is set and a profile overrides :version" do
    Application.put_env(:tailwind, :path, "/tmp/does-not-matter")
    Application.put_env(:tailwind, :pinned, version: "3.4.17", args: [])

    on_exit(fn ->
      Application.delete_env(:tailwind, :path)
      Application.delete_env(:tailwind, :pinned)
    end)

    assert_raise ArgumentError, ~r/cannot configure per-profile :version/, fn ->
      Tailwind.install("https://example.invalid/$version/$target", "3.4.17")
    end
  end

  test "does not raise when :path is set but no profile overrides :version" do
    Application.put_env(:tailwind, :path, Tailwind.bin_path())

    on_exit(fn -> Application.delete_env(:tailwind, :path) end)

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ @version
  end

  test "bin_path/1 keeps the executable extension after the version" do
    Application.put_env(:tailwind, :target, "windows-x64.exe")
    on_exit(fn -> Application.delete_env(:tailwind, :target) end)

    assert Path.basename(Tailwind.bin_path()) == "tailwind-windows-x64-#{@version}.exe"
  end

  test "bin_path/1 appends the version for targets without an extension" do
    Application.put_env(:tailwind, :target, "linux-x64")
    on_exit(fn -> Application.delete_env(:tailwind, :target) end)

    assert Path.basename(Tailwind.bin_path()) == "tailwind-linux-x64-#{@version}"
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

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ @version
  end
end
