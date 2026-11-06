defmodule Juliet.Stanza.IQ do
  use Juliet.XML

  @type jid :: Juliet.JID.t()

  @type t :: %__MODULE__{
          id: binary,
          to: jid,
          from: jid,
          type: binary,
          items: list | nil,
          xml: tuple
        }

  defstruct id: nil,
            to: nil,
            from: nil,
            type: nil,
            items: nil,
            xml: nil
end
