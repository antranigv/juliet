defmodule Juliet.Connection.FeaturesTest do
  use ExUnit.Case, async: true

  alias Juliet.Connection.Features

  test "parses stream features" do
    features =
      {:xmlel, "stream:features", [],
       [
         {:xmlel, "starttls", [{"xmlns", "urn:ietf:params:xml:ns:xmpp-tls"}], []},
         {:xmlel, "mechanisms", [{"xmlns", "urn:ietf:params:xml:ns:xmpp-sasl"}],
          [
            {:xmlel, "mechanism", [], [{:xmlcdata, "SCRAM-SHA-256"}]},
            {:xmlel, "mechanism", [], [{:xmlcdata, "PLAIN"}]}
          ]},
         {:xmlel, "bind", [{"xmlns", "urn:ietf:params:xml:ns:xmpp-bind"}], []}
       ]}

    parsed = Features.parse_stream_features(features)
    assert parsed.tls?
    assert parsed.mechanisms == ["SCRAM-SHA-256", "PLAIN"]
  end

  test "supported auth mechanisms default to empty" do
    assert Features.parse_stream_features({:xmlel, "stream:features", [], []}).mechanisms == []
  end
end
