defmodule Juliet.Roster.Item do
  @type jid :: Juliet.JID.t()

  @type t :: %__MODULE__{
          subscription: binary,
          name: binary,
          jid: jid,
          group: binary,
          xml: tuple
        }

  defstruct subscription: nil,
            name: nil,
            jid: nil,
            group: nil,
            xml: nil
end
