defmodule TailwindTest do
  use ExUnit.Case, async: true

  @version Tailwind.latest_version()

  setup do
    Application.put_env(:tailwind, :version, @version)
    File.mkdir_p!("assets/js")
    File.mkdir_p!("assets/css")
    File.rm("assets/css/app.css")
    :ok
  end

  test "run on default" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ @version
  end

  test "run on profile" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:another, []) == 0
           end) =~ @version
  end

  test "run with pre-existing app.css" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, []) == 0
           end) =~ @version
  end

  test "updates on install" do
    Application.put_env(:tailwind, :version, "3.4.17")
    Mix.Task.rerun("tailwind.install", ["--if-missing"])

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

  test "install on existing app.css and app.js" do
    File.write!("assets/css/app.css", """
    @import "./phoenix.css";
    body {
    }
    """)

    File.write!("assets/js/app.js", """
    import "../css/app.css"

    let Hooks = {}
    """)

    Mix.Task.rerun("tailwind.install")

    expected_css =
      String.trim("""
      @import "tailwindcss";
      @plugin "@tailwindcss/forms";
      @variant phx-click-loading ([".phx-click-loading&", ".phx-click-loading &"]);
      @variant phx-submit-loading ([".phx-submit-loading&", ".phx-submit-loading &"]);
      @variant phx-change-loading ([".phx-change-loading&", ".phx-change-loading &"]);

      body {
      }
      """)

    expected_js =
      String.trim("""

      let Hooks = {}
      """)

    assert String.trim(File.read!("assets/css/app.css")) == expected_css
    assert String.trim(File.read!("assets/js/app.js")) == expected_js

    Mix.Task.rerun("tailwind.install")

    assert String.trim(File.read!("assets/js/app.js")) == expected_js
  end

  test "installs with custom URL" do
    assert :ok =
             Mix.Task.rerun("tailwind.install", [
               "https://github.com/tailwindlabs/tailwindcss/releases/download/v$version/tailwindcss-$target"
             ])
  end
end
