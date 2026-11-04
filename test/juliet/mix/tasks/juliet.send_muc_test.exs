defmodule Juliet.Mix.Tasks.Juliet.SendMucTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Juliet.SendMuc

  @env_vars [
    "JULIET_JID",
    "JULIET_PASSWORD",
    "JULIET_ROOM",
    "JULIET_NICK",
    "JULIET_HOST",
    "JULIET_PORT",
    "JULIET_INSECURE"
  ]

  setup do
    original = Map.new(@env_vars, fn key -> {key, System.get_env(key)} end)

    System.put_env("JULIET_JID", "juliet@capulet.lit")
    System.put_env("JULIET_PASSWORD", "secret")
    System.put_env("JULIET_ROOM", "library@muc.capulet.lit")
    System.put_env("JULIET_NICK", "juliet")
    System.delete_env("JULIET_HOST")
    System.delete_env("JULIET_PORT")
    System.delete_env("JULIET_INSECURE")

    on_exit(fn ->
      for {key, value} <- original do
        if value, do: System.put_env(key, value), else: System.delete_env(key)
      end
    end)

    :ok
  end

  describe "parse_args/1" do
    test "returns the first argument as the message" do
      assert SendMuc.parse_args(["hello"]) == "hello"
    end

    test "raises when no message is given" do
      assert_raise Mix.Error, fn ->
        SendMuc.parse_args([])
      end
    end
  end

  describe "config_from_env/0" do
    test "returns required config" do
      assert SendMuc.config_from_env() == [
               jid: "juliet@capulet.lit",
               password: "secret",
               room: "library@muc.capulet.lit",
               nick: "juliet"
             ]
    end

    test "includes optional host and port" do
      System.put_env("JULIET_HOST", "capulet.lit")
      System.put_env("JULIET_PORT", "5223")

      config = SendMuc.config_from_env()
      assert config[:host] == "capulet.lit"
      assert config[:port] == 5223
    end

    test "disables TLS verification when insecure is true" do
      System.put_env("JULIET_INSECURE", "true")

      config = SendMuc.config_from_env()
      assert config[:ssl_opts] == [verify: :verify_none]
    end

    test "disables TLS verification when insecure is 1" do
      System.put_env("JULIET_INSECURE", "1")

      config = SendMuc.config_from_env()
      assert config[:ssl_opts] == [verify: :verify_none]
    end

    test "leaves verification enabled by default" do
      refute Keyword.has_key?(SendMuc.config_from_env(), :ssl_opts)
    end
  end
end
