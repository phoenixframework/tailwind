defmodule TailwindTest do
  use ExUnit.Case, async: true

  @version Tailwind.latest_version()

  setup do
    Application.put_env(:tailwind, :version, @version)
    File.mkdir_p!("assets/js")
    File.mkdir_p!("assets/css")
    File.rm("assets/tailwind.config.js")
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
    Application.put_env(:tailwind, :version, "3.0.3")
    Mix.Task.rerun("tailwind.install", ["--if-missing"])

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ "3.0.3"

    Application.delete_env(:tailwind, :version)

    Mix.Task.rerun("tailwind.install", ["--if-missing"])
    assert File.exists?("assets/tailwind.config.js")
    assert File.read!("assets/css/app.css") =~ "tailwind"

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ @version
  end

  test "install on existing app.css and app.js" do
    File.write!("assets/css/app.css", """
    @import "./phoenix.css";
    @import "./custom.css";
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
      @import "tailwindcss/base";
      @import "tailwindcss/components";
      @import "tailwindcss/utilities";

      /* Tailwind CLI does not support local @import; merge the file into app.css or see Tailwind documentation */
      /* @import "./phoenix.css"; */

      /* Tailwind CLI does not support local @import; merge the file into app.css or see Tailwind documentation */
      /* @import "./custom.css"; */

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
end
