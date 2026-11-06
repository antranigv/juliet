defmodule Juliet.MUCTest do
  use ExUnit.Case, async: true
  use Juliet.XML

  alias Juliet.MUC

  test "join sends a MUC join presence" do
    pid = spawn_fake_connection()
    room = "library@muc.capulet.lit"
    nick = "juliet"

    assert :ok = MUC.join(pid, room, nick)
    assert_receive {:send, stanza}, 1_000

    assert elem(stanza, 1) == "presence"
    assert Juliet.XML.attr(stanza, "to") == "library@muc.capulet.lit/juliet"

    x = Juliet.XML.subelement(stanza, "x")
    assert Juliet.XML.attr(x, "xmlns") == ns_muc()
    assert Juliet.XML.subelement(x, "history") |> is_tuple()
  end

  test "send waits for self-presence then sends a groupchat message" do
    pid = spawn_fake_connection()
    room = "library@muc.capulet.lit"
    nick = "juliet"

    send(self(), {:stanza, self_presence(room, nick)})

    assert :ok = MUC.send(pid, room, "hello")
    assert_receive {:send, stanza}, 1_000

    assert elem(stanza, 1) == "message"
    assert Juliet.XML.attr(stanza, "to") == room
    assert Juliet.XML.attr(stanza, "type") == "groupchat"
    assert Juliet.XML.cdata(Juliet.XML.subelement(stanza, "body")) == "hello"
  end

  test "send returns timeout when self-presence is not received" do
    pid = spawn_fake_connection()
    room = "library@muc.capulet.lit"

    assert {:error, :timeout} = MUC.send(pid, room, "hello", timeout: 50)
    refute_receive {:send, _}, 100
  end

  test "send ignores non-self-presence messages" do
    pid = spawn_fake_connection()
    room = "library@muc.capulet.lit"
    nick = "juliet"

    other =
      self_presence(room, nick)
      |> Map.update!(:xml, fn xml ->
        children = elem(xml, 3) |> Enum.reject(fn child -> elem(child, 1) == "x" end)
        put_elem(xml, 3, children)
      end)

    send(self(), {:stanza, other})
    send(self(), {:stanza, self_presence(room, nick)})

    assert :ok = MUC.send(pid, room, "hello", timeout: 500)
  end

  defp spawn_fake_connection do
    parent = self()

    spawn(fn -> receive_loop(parent) end)
  end

  defp receive_loop(parent) do
    receive do
      {:"$gen_call", from, {:send, stanza}} ->
        Connection.reply(from, :ok)
        send(parent, {:send, stanza})
        receive_loop(parent)

      :stop ->
        :ok
    end
  end

  defp self_presence(room, nick) do
    xml =
      xmlel(
        name: "presence",
        attrs: [{"from", "#{room}/#{nick}"}],
        children: [
          xmlel(
            name: "x",
            attrs: [{"xmlns", ns_muc_user()}],
            children: [
              xmlel(name: "status", attrs: [{"code", "110"}])
            ]
          )
        ]
      )

    Juliet.Stanza.Parser.parse(xml)
  end
end
