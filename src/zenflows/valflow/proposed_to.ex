defmodule Zenflows.Valflow.ProposedTo do
@moduledoc """
An agent to which the proposal is to be published.  A proposal can be
published to many agents.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{Agent, Proposal}

@type t() :: %__MODULE__{
	proposed_to: Agent.t(),
	proposed: Proposal.t(),
}

schema "vf_proposed_to" do
	belongs_to :proposed_to, Agent
	belongs_to :proposed, Proposal
end

@reqr ~w[proposed_to_id proposed_id]a
@cast @reqr

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.assoc_constraint(:proposed_to)
	|> Changeset.assoc_constraint(:proposed)
end
end
