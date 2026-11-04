defmodule Juliet.Auth.SCRAMTest do
  use ExUnit.Case, async: true

  alias Juliet.Auth.SCRAM

  describe "RFC test vectors" do
    test "RFC 5802 SCRAM-SHA-1" do
      {gs2, bare, first} = SCRAM.client_first_message("user", "fyko+d2lbbFgONRv9qkxdawL")

      assert first == "n,,n=user,r=fyko+d2lbbFgONRv9qkxdawL"

      server_first =
        "r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,s=QSXCR+Q6sek8bf92,i=4096"

      {client_final, server_signature} =
        SCRAM.client_final_message(
          :sha,
          "pencil",
          bare,
          server_first,
          gs2,
          "fyko+d2lbbFgONRv9qkxdawL"
        )

      assert client_final ==
               "c=biws,r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,p=v0X8v3Bz2T0CJGbJQyF0X+HI4Ts="

      assert server_signature == "rmF9pqV8S7suAoZWja4dJRkFsKQ="
      assert SCRAM.verify_server_signature!("v=" <> server_signature, server_signature) == :ok
    end

    test "RFC 7677 SCRAM-SHA-256" do
      {gs2, bare, first} = SCRAM.client_first_message("user", "rOprNGfwEbeRWgbNEkqO")

      assert first == "n,,n=user,r=rOprNGfwEbeRWgbNEkqO"

      server_first =
        "r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096"

      {client_final, server_signature} =
        SCRAM.client_final_message(
          :sha256,
          "pencil",
          bare,
          server_first,
          gs2,
          "rOprNGfwEbeRWgbNEkqO"
        )

      assert client_final ==
               "c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,p=dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ="

      assert server_signature == "6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4="
      assert SCRAM.verify_server_signature!("v=" <> server_signature, server_signature) == :ok
    end
  end

  describe "username escaping" do
    test "escapes '=' and ',' in usernames" do
      {_gs2, bare, _first} = SCRAM.client_first_message("user=1,2", "nonce")
      assert bare == "n=user=3D1=2C2,r=nonce"
    end
  end

  describe "full SASL exchange" do
    test "successful SCRAM-SHA-1 authentication" do
      nonce = "fyko+d2lbbFgONRv9qkxdawL"

      server_first =
        "r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,s=QSXCR+Q6sek8bf92,i=4096"

      {_gs2, bare, _first} = SCRAM.client_first_message("user", nonce)

      {_client_final, server_signature} =
        SCRAM.client_final_message(:sha, "pencil", bare, server_first, "n,,", nonce)

      conn =
        %Juliet.Connection{
          jid: "user@example.com",
          password: "pencil",
          transport: __MODULE__.FakeTransport
        }
        |> Map.put(:scram_nonce, nonce)

      Process.put(:fake_receives, [
        {:xmlel, "challenge", [], [{:xmlcdata, Base.encode64(server_first)}]},
        {:xmlel, "success", [], [{:xmlcdata, Base.encode64("v=" <> server_signature)}]}
      ])

      assert {:ok, _conn, :done} = SCRAM.authenticate("SCRAM-SHA-1", conn)

      [auth, response] = Process.get(:fake_sends) |> Enum.reverse()

      assert elem(auth, 1) == "auth"
      assert Juliet.XML.cdata(auth) |> Base.decode64!() == "n,,n=user,r=" <> nonce

      assert elem(response, 1) == "response"
      response_cdata = Juliet.XML.cdata(response) |> Base.decode64!()
      assert response_cdata =~ "p=v0X8v3Bz2T0CJGbJQyF0X+HI4Ts="
    end

    test "raises when the server signature does not match" do
      nonce = "fyko+d2lbbFgONRv9qkxdawL"

      server_first =
        "r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,s=QSXCR+Q6sek8bf92,i=4096"

      conn =
        %Juliet.Connection{
          jid: "user@example.com",
          password: "pencil",
          transport: __MODULE__.FakeTransport
        }
        |> Map.put(:scram_nonce, nonce)

      Process.put(:fake_receives, [
        {:xmlel, "challenge", [], [{:xmlcdata, Base.encode64(server_first)}]},
        {:xmlel, "success", [], [{:xmlcdata, Base.encode64("v=dGVzdA==")}]}
      ])

      assert_raise Juliet.Auth.Error, ~r/server signature/, fn ->
        SCRAM.authenticate("SCRAM-SHA-1", conn)
      end
    end

    test "raises on SASL failure" do
      nonce = "fyko+d2lbbFgONRv9qkxdawL"

      server_first =
        "r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,s=QSXCR+Q6sek8bf92,i=4096"

      conn =
        %Juliet.Connection{
          jid: "user@example.com",
          password: "pencil",
          transport: __MODULE__.FakeTransport
        }
        |> Map.put(:scram_nonce, nonce)

      Process.put(:fake_receives, [
        {:xmlel, "challenge", [], [{:xmlcdata, Base.encode64(server_first)}]},
        {:xmlel, "failure", [], [{:xmlcdata, "not-authorized"}]}
      ])

      assert_raise Juliet.Auth.Error, ~r/not-authorized/, fn ->
        SCRAM.authenticate("SCRAM-SHA-1", conn)
      end
    end
  end

  defmodule FakeTransport do
    def send(conn, stanza) do
      sends = Process.get(:fake_sends, [])
      Process.put(:fake_sends, [stanza | sends])
      {:ok, conn}
    end

    def recv(conn, fun) do
      [stanza | rest] = Process.get(:fake_receives)
      Process.put(:fake_receives, rest)
      fun.(conn, stanza)
    end
  end
end
