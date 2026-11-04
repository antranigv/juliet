defmodule Juliet.Stanza.ParserTest do
  use ExUnit.Case, async: true

  use Juliet.XML

  alias Juliet.Stanza.Parser

  @iq {:xmlel, "iq",
       [
         {"from", "im.test.dev"},
         {"to", "scrogson@im.test.dev/issues"},
         {"id", "b0e3"},
         {"type", "result"}
       ],
       [
         {:xmlel, "query", [{"xmlns", "http://jabber.org/protocol/disco#items"}],
          [
            {:xmlel, "item", [{"jid", "conference.im.test.dev"}], []},
            {:xmlel, "item", [{"jid", "pubsub.im.test.dev"}], []}
          ]}
       ]}

  test "it parses stanzas" do
    parsed = Parser.parse(@iq)
    assert parsed.type == "result"
    assert parsed.id == "b0e3"
    assert %Juliet.JID{user: "scrogson", server: "im.test.dev", resource: "issues"} = parsed.to
    assert %Juliet.JID{user: "", server: "im.test.dev", resource: ""} = parsed.from
    xmlel(name: "iq") = parsed.xml

    query = Juliet.XML.subelement(parsed.xml, "query")
    assert Enum.count(xmlel(query, :children)) == 2
  end
end
