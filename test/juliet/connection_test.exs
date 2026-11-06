defmodule Juliet.ConnectionTest do
  use ExUnit.Case, async: true

  alias Juliet.Connection

  test "default connection struct" do
    conn = %Connection{}
    assert conn.features == %Juliet.Connection.Features{}
    assert conn.resource == ""
    assert conn.rooms == []
  end
end
