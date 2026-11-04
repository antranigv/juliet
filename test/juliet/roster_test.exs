defmodule Juliet.RosterTest do
  use ExUnit.Case, async: true

  use Juliet.XML

  alias Juliet.Roster.Item
  alias Juliet.Stanza

  test "set_roster_item builds a roster set stanza" do
    xml = Stanza.set_roster_item("juliet@capulet.lit", "both", "Juliet", "buddies")

    assert Stanza.to_xml(xml) =~
             ~r"<iq type='set' id='(.*)'><query xmlns='jabber:iq:roster'><item jid='juliet@capulet.lit' subscription='both' name='Juliet'><group>buddies</group></item></query></iq>"
  end

  test "get_roster builds a roster get stanza" do
    xml = Stanza.get_roster()

    assert Stanza.to_xml(xml) =~
             ~r"<iq type='get' id='(.*)'><query xmlns='jabber:iq:roster'/></iq>"
  end

  test "parser extracts roster items from a roster result" do
    stanza =
      {:xmlel, "iq",
       [{"from", "capulet.lit"}, {"to", "juliet@capulet.lit"}, {"id", "r1"}, {"type", "result"}],
       [
         {:xmlel, "query", [{"xmlns", "jabber:iq:roster"}],
          [
            {:xmlel, "item",
             [{"jid", "romeo@montague.lit"}, {"subscription", "both"}, {"name", "Romeo"}], []},
            {:xmlel, "item",
             [{"jid", "mercutio@montague.lit"}, {"subscription", "both"}, {"name", "Mercutio"}],
             []}
          ]}
       ]}

    parsed = Juliet.Stanza.Parser.parse(stanza)
    assert parsed.type == "result"
    assert [%Item{name: "Mercutio"}, %Item{name: "Romeo"}] = parsed.items
  end
end
