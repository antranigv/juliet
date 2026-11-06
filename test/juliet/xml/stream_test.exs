defmodule Juliet.XML.StreamTest do
  use ExUnit.Case, async: true

  alias Juliet.XML.Stream

  defp fixture(name) do
    Path.join([__DIR__, "..", "..", "fixtures", name])
    |> File.read!()
  end

  test "parses a stream header" do
    parser = Stream.new(self())
    {:ok, parser} = Stream.parse(parser, fixture("stream_header.xml"))

    assert_receive {:xmlstreamstart, "stream:stream", attrs}
    assert {"id", "test-stream-id"} in attrs
    assert {"from", "capulet.lit"} in attrs
    assert {"version", "1.0"} in attrs

    # Keep-alive whitespace should be ignored.
    {:ok, _parser} = Stream.parse(parser, "  \n  ")
    refute_receive {:xmlstreamelement, _}
  end

  test "parses stream features" do
    parser = Stream.new(self())
    {:ok, parser} = Stream.parse(parser, fixture("stream_header.xml"))
    assert_receive {:xmlstreamstart, "stream:stream", _}

    {:ok, _parser} = Stream.parse(parser, fixture("features.xml"))

    assert_receive {:xmlstreamelement, {:xmlel, "stream:features", _, children}}

    assert Enum.any?(children, fn
             {:xmlel, "starttls", [{"xmlns", "urn:ietf:params:xml:ns:xmpp-tls"}], _} -> true
             _ -> false
           end)
  end

  test "parses a success element" do
    parser = Stream.new(self())
    {:ok, parser} = Stream.parse(parser, fixture("stream_header.xml"))
    assert_receive {:xmlstreamstart, "stream:stream", _}

    {:ok, _parser} = Stream.parse(parser, fixture("success.xml"))

    assert_receive {:xmlstreamelement,
                    {:xmlel, "success", [{"xmlns", "urn:ietf:params:xml:ns:xmpp-sasl"}], _}}
  end

  test "parses a message stanza" do
    parser = Stream.new(self())
    {:ok, parser} = Stream.parse(parser, fixture("stream_header.xml"))
    assert_receive {:xmlstreamstart, "stream:stream", _}

    {:ok, _parser} = Stream.parse(parser, fixture("message.xml"))

    assert_receive {:xmlstreamelement, {:xmlel, "message", attrs, children}}
    assert {"type", "chat"} in attrs
    assert {"id", "msg1"} in attrs

    body = Juliet.XML.subelement({:xmlel, "message", attrs, children}, "body")
    assert Juliet.XML.cdata(body) == "Where art thou?"
  end

  test "parses a presence stanza" do
    parser = Stream.new(self())
    {:ok, parser} = Stream.parse(parser, fixture("stream_header.xml"))
    assert_receive {:xmlstreamstart, "stream:stream", _}

    {:ok, _parser} = Stream.parse(parser, fixture("presence.xml"))

    assert_receive {:xmlstreamelement, {:xmlel, "presence", attrs, _}}
    assert {"type", "subscribe"} in attrs
  end

  test "handles stanzas split across chunks" do
    parser = Stream.new(self())
    {:ok, parser} = Stream.parse(parser, fixture("stream_header.xml"))
    assert_receive {:xmlstreamstart, "stream:stream", _}

    message = fixture("message.xml")
    {chunk1, chunk2} = String.split_at(message, div(byte_size(message), 2))

    {:ok, parser} = Stream.parse(parser, chunk1)
    refute_receive {:xmlstreamelement, _}, 50

    {:ok, _parser} = Stream.parse(parser, chunk2)
    assert_receive {:xmlstreamelement, {:xmlel, "message", _, _}}
  end

  test "handles multiple stanzas in one chunk" do
    parser = Stream.new(self())
    {:ok, parser} = Stream.parse(parser, fixture("stream_header.xml"))
    assert_receive {:xmlstreamstart, "stream:stream", _}

    chunk = fixture("message.xml") <> fixture("presence.xml")
    {:ok, _parser} = Stream.parse(parser, chunk)

    assert_receive {:xmlstreamelement, {:xmlel, "message", _, _}}
    assert_receive {:xmlstreamelement, {:xmlel, "presence", _, _}}
  end

  test "handles unicode / Armenian text" do
    parser = Stream.new(self())
    {:ok, parser} = Stream.parse(parser, fixture("stream_header.xml"))
    assert_receive {:xmlstreamstart, "stream:stream", _}

    {:ok, _parser} = Stream.parse(parser, fixture("unicode.xml"))

    assert_receive {:xmlstreamelement, {:xmlel, "message", _, children}}
    body = Juliet.XML.subelement({:xmlel, "message", [], children}, "body")
    assert Juliet.XML.cdata(body) == "Բարև աշխարհ"
  end

  test "reset creates a fresh parser" do
    parser = Stream.new(self())
    {:ok, parser} = Stream.parse(parser, fixture("stream_header.xml"))
    assert_receive {:xmlstreamstart, "stream:stream", _}

    parser = Stream.reset(parser)
    {:ok, _parser} = Stream.parse(parser, fixture("stream_header.xml"))
    assert_receive {:xmlstreamstart, "stream:stream", _}
  end
end
