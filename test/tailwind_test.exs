defmodule TailwindTest do
  use ExUnit.Case, async: true

  @version Tailwind.latest_version()

  test "run on default" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ @version
    assert File.exists?("assets/tailwind.config.js")
  end

  test "does not overwrite existing assets/tailwind.config.js" do
    assert ExUnit.CaptureIO.capture_io(fn ->
      assert Tailwind.run(:default, ["--help"]) == 0
    end) =~ @version

    contents = """
      module.exports = {
        content: [
          './js/**/*.js',
          '../lib/*_web.ex',
          '../lib/*_web/**/*.*ex'
        ],
        theme: {
          zIndex: {
            '0': 0,
            '10': 10,
            '20': 20,
            '30': 30,
            '40': 40,
            '50': 50,
          },
          extend: {},
        },
        plugins: [
          require('@tailwindcss/forms')
        ]
      }
    """

    File.write!("assets/tailwind.config.js", contents)

    assert File.read!("assets/tailwind.config.js") == contents
  end

  test "run on profile" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:another, []) == 0
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

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Tailwind.run(:default, ["--help"]) == 0
           end) =~ @version
  end
end
