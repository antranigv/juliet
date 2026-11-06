defmodule Juliet.Auth do
  @moduledoc """
  Handles XMPP authentication mechanisms.
  """

  use Juliet.XML
  require Logger

  defmodule Mechanism do
    @doc "Authenticates using the supplied mechanism"
    @callback authenticate(String.t(), Juliet.Connection.t()) :: Juliet.Connection.t()
  end

  defmodule Error do
    defexception [:message]

    def exception(mechanism) do
      msg = "Failed to authenticate using mechanism: #{inspect(mechanism)}"
      %Juliet.Auth.Error{message: msg}
    end
  end

  @doc """
  Authenticates the client using the configured preferred mechanism.

  Preferred mechanisms can be set via the `:preferred_auth_mechanisms` option.
  When left empty the library prefers SCRAM-SHA-256, then SCRAM-SHA-1, and
  finally falls back to PLAIN.

  If the preferred mechanism is not supported it will choose PLAIN.
  """
  def authenticate!(conn) do
    preferred = conn.preferred_auth_mechanisms
    mechanisms = conn.features.mechanisms
    preferred_mechanism(preferred, mechanisms) |> do_authenticate(conn)
  end

  def handshake!(%{transport: mod, password: password, stream_id: stream_id} = conn) do
    stanza =
      :crypto.hash(:sha, "#{stream_id}#{password}")
      |> Base.encode16(case: :lower)
      |> Stanza.handshake()

    conn
    |> mod.send(stanza)
    |> mod.recv(fn
      conn, xmlel(name: "handshake") ->
        conn

      _conn, xmlel(name: "stream:error") ->
        raise Juliet.Auth.Error, "handshake error"
    end)
  end

  defp do_authenticate(mechanism, conn) do
    result =
      case mechanism do
        {name, mod} ->
          Logger.info(fn -> "Authenticating with extension #{name} implemented by #{mod}" end)
          mod.authenticate(name, conn)

        _ ->
          Logger.info(fn -> "Authenticating with #{mechanism}" end)
          authenticate_with(mechanism, conn)
      end

    case result do
      {:ok, conn} ->
        case success?(conn) do
          {:ok, conn} -> conn
          {:error, _conn} -> raise Juliet.Auth.Error, mechanism
        end

      {:ok, conn, :done} ->
        conn
    end
  end

  defp authenticate_with("SCRAM-SHA-256", conn) do
    Juliet.Auth.SCRAM.authenticate("SCRAM-SHA-256", conn)
  end

  defp authenticate_with("SCRAM-SHA-1", conn) do
    Juliet.Auth.SCRAM.authenticate("SCRAM-SHA-1", conn)
  end

  defp authenticate_with("PLAIN", %{transport: mod} = conn) do
    [username, password] = get_client_credentials(conn)
    payload = <<0>> <> username <> <<0>> <> password
    mod.send(conn, Juliet.Stanza.auth("PLAIN", Juliet.Stanza.base64_cdata(payload)))
  end

  defp authenticate_with("ANONYMOUS", %{transport: mod} = conn) do
    conn |> mod.send(Juliet.Stanza.auth("ANONYMOUS"))
  end

  defp authenticate_with(mechanism_name, _conn) do
    raise """
      Juliet does not include an implementation for authentication mechanism #{inspect(mechanism_name)}.
      Please provide an implementation such as

        Juliet.Connection.start_link(preferred_auth_mechanisms: [{#{inspect(mechanism_name)}, SomeModule}])

      where `SomeModule` implements the Juliet.Auth.Mechanism behaviour.
    """
  end

  defp success?(%{transport: mod} = conn) do
    mod.recv(conn, fn conn, xmlel(name: name) ->
      case name do
        "success" ->
          Logger.info(fn -> "Authenticated successfully" end)
          {:ok, conn}

        "failure" ->
          {:error, conn}
      end
    end)
  end

  defp get_client_credentials(%{jid: jid, password: password}) do
    [Juliet.JID.parse(jid).user, password]
  end

  @doc false
  def preferred_mechanism([], mechanisms),
    do: preferred_mechanism(["SCRAM-SHA-256", "SCRAM-SHA-1", "PLAIN"], mechanisms)

  def preferred_mechanism([mechanism | tail], mechanisms) do
    case acceptable_mechanism?(mechanism, mechanisms) do
      true -> mechanism
      false -> preferred_mechanism(tail, mechanisms)
    end
  end

  defp acceptable_mechanism?({name, _mod}, mechanisms),
    do: acceptable_mechanism?(name, mechanisms)

  defp acceptable_mechanism?(mechanism, mechanisms),
    do: Enum.member?(mechanisms, mechanism)
end
