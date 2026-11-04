defmodule Juliet.XMLTest do
  use ExUnit.Case, async: true

  use Juliet.XML
  import Juliet.XML

  test "encode!" do
    xml =
      xmlel(
        name: "message",
        children: [
          xmlel(
            name: "body",
            children: [
              xmlcdata(content: "testing")
            ]
          )
        ]
      )

    assert encode!(xml) ==
             ~s(<message><body>testing</body></message>)
  end

  test "attr" do
    xml = xmlel(name: "message", attrs: [{"type", "chat"}])
    assert attr(xml, "type") == "chat"
    assert attr(xml, "non-existent") == nil
    assert attr(xml, "non-existent", "default") == "default"
  end

  test "subelement" do
    xml =
      xmlel(
        name: "message",
        children: [
          xmlel(
            name: "body",
            children: [
              xmlcdata(content: "testing")
            ]
          )
        ]
      )

    assert subelement(xml, "body") ==
             {:xmlel, "body", [], [xmlcdata(content: "testing")]}

    assert subelement(xml, "non-existent") == nil
    assert subelement(xml, "non-existent", []) == []
  end

  test "cdata" do
    body =
      xmlel(
        name: "body",
        children: [
          xmlcdata(content: "testing")
        ]
      )

    assert cdata(body) == "testing"
  end

  test "empty cdata" do
    body =
      xmlel(
        name: "body",
        children: [
          xmlcdata(content: "testing")
        ]
      )

    assert cdata(body) == "testing"
  end

  test "parse/encode round-trip" do
    xml =
      Path.join([__DIR__, "..", "fixtures", "message.xml"])
      |> File.read!()
      |> parse_element()

    encoded = encode!(xml)
    assert encoded =~ "<message"
    assert encoded =~ "<body>Where art thou?</body>"
    assert encoded == encoded |> parse_element() |> encode!()
  end
end
