defmodule Juliet.DocsTest do
  use ExUnit.Case

  @moduletag :documentation

  describe "README.md" do
    setup do
      {:ok, content: File.read!("README.md")}
    end

    test "explains what Juliet is and credits Romeo", %{content: content} do
      assert content =~ "Juliet is a fork of"
      assert content =~ "Romeo"
      assert content =~ "Antranig Vartanian"
      assert content =~ "pure Elixir"
    end

    test "contains installation instructions", %{content: content} do
      assert content =~ "## Installation"
      assert content =~ "{:juliet, \"~> 0.1\"}"
    end

    test "contains a MUC quick start", %{content: content} do
      assert content =~ "## Quick start: send a message to a MUC room"
      assert content =~ "Juliet.Connection"
      assert content =~ "MUC.join"
      assert content =~ "MUC.send"
      assert content =~ ":connection_ready"
    end

    test "documents TLS options", %{content: content} do
      assert content =~ "## TLS options"
      assert content =~ "verify_peer"
      assert content =~ "ssl_opts: [verify: :verify_none]"
    end

    test "documents authentication options", %{content: content} do
      assert content =~ "## Authentication"
      assert content =~ "SCRAM-SHA-256"
      assert content =~ "PLAIN"
      assert content =~ "preferred_auth_mechanisms"
    end

    test "contains a fork note and credits", %{content: content} do
      assert content =~ "## Fork note and credits"
      assert content =~ "Sonny Scroggin"
    end
  end

  describe "CHANGELOG.md" do
    setup do
      {:ok, content: File.read!("CHANGELOG.md")}
    end

    test "contains a v0.1.0 entry", %{content: content} do
      assert content =~ "## v0.1.0"
    end

    test "v0.1.0 lists the required changes", %{content: content} do
      v0_1_0 = v0_1_0_section(content)

      assert v0_1_0 =~ "Fork from Romeo"
      assert v0_1_0 =~ "saxy"
      assert v0_1_0 =~ "TLS"
      assert v0_1_0 =~ "SCRAM"
      assert v0_1_0 =~ "MUC"
    end
  end

  describe "MIGRATING.md" do
    setup do
      {:ok, content: File.read!("MIGRATING.md")}
    end

    test "exists and explains the module rename", %{content: content} do
      assert File.exists?("MIGRATING.md")
      assert content =~ "Romeo.Connection"
      assert content =~ "Juliet.Connection"
    end

    test "documents the dependency and config rename", %{content: content} do
      assert content =~ ":romeo"
      assert content =~ ":juliet"
      assert content =~ "config :juliet"
    end

    test "documents the TLS verification behavior change", %{content: content} do
      assert content =~ "TLS verification is enabled by default"
      assert content =~ "verify: :verify_none"
    end

    test "documents the authentication preference", %{content: content} do
      assert content =~ "SCRAM-SHA-256"
      assert content =~ "PLAIN"
      assert content =~ "preferred_auth_mechanisms"
    end
  end

  defp v0_1_0_section(content) do
    [header | rest] = String.split(content, "## v0.1.0")
    section = List.first(rest)

    [next_section | _] =
      Regex.split(~r/\n## v\d+\.\d+\.\d+/, section, parts: 2, include_captures: true)

    next_section
  end
end
