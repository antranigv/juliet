defmodule Juliet.AuthTest do
  use ExUnit.Case, async: true

  use Juliet.XML

  alias Juliet.Connection.Features

  describe "mechanism selection" do
    test "prefers SCRAM-SHA-256, then SCRAM-SHA-1, then PLAIN by default" do
      mechanisms = mechanisms_from_fixture("features.xml")

      assert Juliet.Auth.preferred_mechanism([], mechanisms) == "SCRAM-SHA-256"
    end

    test "respects an explicit preference list" do
      mechanisms = mechanisms_from_fixture("features.xml")

      assert Juliet.Auth.preferred_mechanism(["SCRAM-SHA-1"], mechanisms) == "SCRAM-SHA-1"
      assert Juliet.Auth.preferred_mechanism(["PLAIN"], mechanisms) == "PLAIN"
    end

    test "falls back to PLAIN when preferred mechanisms are unavailable" do
      mechanisms = ["PLAIN", "ANONYMOUS"]

      assert Juliet.Auth.preferred_mechanism([], mechanisms) == "PLAIN"
      assert Juliet.Auth.preferred_mechanism(["SCRAM-SHA-256"], mechanisms) == "PLAIN"
    end

    test "forces a supported mechanism when requested" do
      mechanisms = ["SCRAM-SHA-256", "SCRAM-SHA-1", "PLAIN"]

      assert Juliet.Auth.preferred_mechanism(["SCRAM-SHA-1", "SCRAM-SHA-256"], mechanisms) ==
               "SCRAM-SHA-1"
    end

    test "ignores unsupported mechanisms in the preference list" do
      mechanisms = ["SCRAM-SHA-1", "PLAIN"]

      assert Juliet.Auth.preferred_mechanism(["SCRAM-SHA-256", "SCRAM-SHA-1"], mechanisms) ==
               "SCRAM-SHA-1"
    end
  end

  defp mechanisms_from_fixture(name) do
    name
    |> fixture_path()
    |> File.read!()
    |> Juliet.XML.parse_element()
    |> Features.supported_auth_mechanisms()
  end

  defp fixture_path(name) do
    Path.join([__DIR__, "..", "fixtures", name])
  end
end
