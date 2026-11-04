defmodule Juliet.Auth.SCRAM do
  @moduledoc false

  # SCRAM-SHA-1 and SCRAM-SHA-256 implementation for XMPP SASL
  # (RFC 5802 and RFC 7677).

  use Juliet.XML
  require Logger

  @doc """
  Performs a SCRAM-SHA-1 or SCRAM-SHA-256 authentication exchange over the
  connection's transport.

  Returns `{:ok, conn, :done}` on success so that `Juliet.Auth` does not wait
  for an additional success stanza.
  """
  def authenticate(mechanism, conn) do
    hash = hash_for(mechanism)
    username = conn.jid |> Juliet.JID.parse() |> Map.fetch!(:user)
    password = conn.password
    nonce = client_nonce(conn)

    {gs2_header, client_first_bare, client_first} = client_first_message(username, nonce)

    conn = send_auth(conn, mechanism, client_first)

    {conn, server_first} = recv_challenge(conn)
    verify_nonce!(server_first, nonce)

    {client_final, expected_server_signature} =
      client_final_message(hash, password, client_first_bare, server_first, gs2_header, nonce)

    conn = send_response(conn, client_final)

    case recv_success_or_failure(conn) do
      {:success, server_final} ->
        verify_server_signature!(server_final, expected_server_signature)
        {:ok, conn, :done}

      {:failure, reason} ->
        raise Juliet.Auth.Error, "#{mechanism}: #{reason}"
    end
  end

  @doc false
  def client_first_message(username, nonce) do
    gs2_header = "n,,"
    bare = "n=" <> escape_username(username) <> ",r=" <> nonce
    {gs2_header, bare, gs2_header <> bare}
  end

  @doc false
  def client_final_message(
        hash,
        password,
        client_first_bare,
        server_first,
        gs2_header,
        client_nonce
      ) do
    %{nonce: server_nonce, salt: salt, iterations: iterations} = parse_server_first(server_first)

    unless String.starts_with?(server_nonce, client_nonce) do
      raise Juliet.Auth.Error, "SCRAM server nonce does not extend client nonce"
    end

    salted_password = :crypto.pbkdf2_hmac(hash, password, salt, iterations, hash_length(hash))

    client_key = :crypto.mac(:hmac, hash, salted_password, "Client Key")
    stored_key = :crypto.hash(hash, client_key)

    client_final_without_proof = client_final_without_proof(gs2_header, server_nonce)
    auth_message = client_first_bare <> "," <> server_first <> "," <> client_final_without_proof

    client_signature = :crypto.mac(:hmac, hash, stored_key, auth_message)
    client_proof = :crypto.exor(client_key, client_signature)

    server_key = :crypto.mac(:hmac, hash, salted_password, "Server Key")
    server_signature = :crypto.mac(:hmac, hash, server_key, auth_message)

    client_final = client_final_without_proof <> ",p=" <> Base.encode64(client_proof)

    {client_final, Base.encode64(server_signature)}
  end

  @doc false
  def verify_server_signature!(server_final_message, expected_server_signature) do
    attrs = split_attrs(server_final_message)

    case Map.fetch(attrs, "v") do
      {:ok, received} ->
        unless Base.decode64!(received) == Base.decode64!(expected_server_signature) do
          raise Juliet.Auth.Error, "SCRAM server signature verification failed"
        end

        :ok

      :error ->
        raise Juliet.Auth.Error, "SCRAM server final message missing server signature"
    end
  end

  defp client_nonce(conn) do
    Map.get(conn, :scram_nonce) || generate_nonce()
  end

  defp generate_nonce do
    :crypto.strong_rand_bytes(24) |> Base.encode64()
  end

  defp hash_for("SCRAM-SHA-1"), do: :sha
  defp hash_for("SCRAM-SHA-256"), do: :sha256

  defp hash_length(hash), do: hash |> :crypto.hash("") |> byte_size()

  defp escape_username(username) do
    username
    |> String.replace("=", "=3D")
    |> String.replace(",", "=2C")
  end

  defp client_final_without_proof(gs2_header, server_nonce) do
    "c=" <> Base.encode64(gs2_header) <> ",r=" <> server_nonce
  end

  defp parse_server_first(message) do
    attrs = split_attrs(message)

    %{
      nonce: Map.fetch!(attrs, "r"),
      salt: Base.decode64!(Map.fetch!(attrs, "s")),
      iterations: String.to_integer(Map.fetch!(attrs, "i"))
    }
  end

  defp split_attrs(message) do
    message
    |> String.split(",")
    |> Enum.map(fn part ->
      [key, value] = String.split(part, "=", parts: 2)
      {key, value}
    end)
    |> Enum.into(%{})
  end

  defp verify_nonce!(server_first, client_nonce) do
    attrs = split_attrs(server_first)
    server_nonce = Map.fetch!(attrs, "r")

    unless String.starts_with?(server_nonce, client_nonce) do
      raise Juliet.Auth.Error, "SCRAM server nonce does not extend client nonce"
    end
  end

  defp send_auth(%{transport: mod} = conn, mechanism, client_first) do
    {:ok, conn} =
      mod.send(
        conn,
        Juliet.Stanza.auth(mechanism, Juliet.Stanza.base64_cdata(client_first))
      )

    conn
  end

  defp send_response(%{transport: mod} = conn, client_final) do
    response =
      xmlel(
        name: "response",
        attrs: [{"xmlns", ns_sasl()}],
        children: [xmlcdata(content: Base.encode64(client_final))]
      )

    {:ok, conn} = mod.send(conn, response)
    conn
  end

  defp recv_challenge(%{transport: mod} = conn) do
    mod.recv(conn, fn conn, stanza ->
      challenge = stanza |> Juliet.XML.cdata() |> Base.decode64!()
      {conn, challenge}
    end)
  end

  defp recv_success_or_failure(%{transport: mod} = conn) do
    mod.recv(conn, fn
      _conn, xmlel(name: "success") = stanza ->
        {:success, stanza |> Juliet.XML.cdata() |> Base.decode64!()}

      _conn, xmlel(name: "failure") = stanza ->
        {:failure, Juliet.XML.cdata(stanza)}
    end)
  end
end
