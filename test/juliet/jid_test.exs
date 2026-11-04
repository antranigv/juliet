defmodule Juliet.JidTest do
  use ExUnit.Case, async: true

  alias Juliet.JID

  doctest Juliet.JID

  test "String.Chars protocol converts structs to binaries" do
    jid = %JID{server: "example.com"}
    assert to_string(jid) == "example.com"

    jid = %JID{user: "jdoe", server: "example.com"}
    assert to_string(jid) == "jdoe@example.com"

    jid = %JID{user: "jdoe", server: "example.com", resource: "library"}
    assert to_string(jid) == "jdoe@example.com/library"
  end

  test "bare returns a JID without a resource" do
    jid = %JID{user: "jdoe", server: "example.com", resource: "library"}
    assert JID.bare(jid) == "jdoe@example.com"
    assert JID.bare("jdoe@example.com/library") == "jdoe@example.com"
    assert JID.bare("jdoe@example.com") == "jdoe@example.com"
  end

  test "it converts binaries into structs" do
    string = "jdoe@example.com"
    assert JID.parse(string) == %JID{user: "jdoe", server: "example.com", full: string}

    string = "jdoe@example.com/library"

    assert JID.parse(string) == %JID{
             user: "jdoe",
             server: "example.com",
             resource: "library",
             full: string
           }

    string = "jdoe@example.com/jdoe@example.com/resource"

    assert JID.parse(string) == %JID{
             user: "jdoe",
             server: "example.com",
             resource: "jdoe@example.com/resource",
             full: string
           }

    string = "example.com"

    assert JID.parse(string) == %JID{
             user: "",
             server: "example.com",
             resource: "",
             full: "example.com"
           }
  end

  test "user/1, server/1, and resource/1 work with structs and binaries" do
    jid = "jdoe@example.com/library"

    assert JID.user(jid) == "jdoe"
    assert JID.server(jid) == "example.com"
    assert JID.resource(jid) == "library"

    parsed = JID.parse(jid)
    assert JID.user(parsed) == "jdoe"
    assert JID.server(parsed) == "example.com"
    assert JID.resource(parsed) == "library"
  end

  test "bare returns a server-only JID unchanged" do
    assert JID.bare("example.com") == "example.com"
  end
end
