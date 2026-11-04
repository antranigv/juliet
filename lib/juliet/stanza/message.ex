defmodule Juliet.Stanza.Message do
  use Juliet.XML

  @type jid :: Juliet.JID.t()

  @type t :: %__MODULE__{
          id: binary,
          to: jid,
          from: jid,
          type: binary,
          body: binary | list,
          html: binary | list | nil,
          xml: tuple,
          delayed?: boolean
        }

  defstruct id: "",
            to: nil,
            from: nil,
            type: "normal",
            body: "",
            html: nil,
            xml: nil,
            delayed?: false
end
