defmodule Zenflows.VF.Appreciation do
@moduledoc """
A way to tie an economic event that is given in loose fulfilment for
another economic event, without commitments or expectations.  Supports the
gift economy.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{EconomicEvent, Validate}

@type t() :: %__MODULE__{
	appreciation_of: EconomicEvent.t(),
	appreciation_with: EconomicEvent.t(),
	note: String.t() | nil,
}

schema "vf_appreciation" do
	belongs_to :appreciation_of, EconomicEvent
	belongs_to :appreciation_with, EconomicEvent
	field :note, :string
end

@reqr ~w[appreciation_of_id appreciation_with_id]a
@cast @reqr ++ [:note]

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:appreciation_of)
	|> Changeset.assoc_constraint(:appreciation_with)
end
end
