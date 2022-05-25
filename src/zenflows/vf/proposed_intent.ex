defmodule Zenflows.VF.ProposedIntent do
@moduledoc """
Represents many-to-many relationships between proposals and intents,
supporting including intents in multiple proposals, as well as a proposal
including multiple intents.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{Intent, Proposal}

@type t() :: %__MODULE__{
	reciprocal: boolean(),
	publishes: Intent.t(),
	published_in: Proposal.t(),
}

schema "vf_proposed_intent" do
	field :reciprocal, :boolean, default: false
	belongs_to :publishes, Intent
	belongs_to :published_in, Proposal
end

@reqr ~w[publishes_id published_in_id]a
@cast @reqr ++ [:reciprocal]

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.assoc_constraint(:publishes)
	|> Changeset.assoc_constraint(:published_in)
end
end
