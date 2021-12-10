defmodule Zenflows.Valflow.AgentRelationship do
@moduledoc """
A relationship role defining the kind of association one agent can have
with another.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	Agent,
	AgentRelationshipRole,
	Validate,
}

@type t() :: %__MODULE__{
	subject: Agent.t(),
	object: Agent.t(),
	relationship: AgentRelationshipRole.t(),
	# in_scope_of
	note: String.t() | nil,
}

schema "vf_agent_relationship" do
	belongs_to :subject, Agent
	belongs_to :object, Agent
	belongs_to :relationship, AgentRelationshipRole
	# in_scope_of
	field :note, :string
end

@reqr ~w[subject_id object_id relationship_id]a
@cast @reqr ++ [:note] # in_scope_of

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:subject)
	|> Changeset.assoc_constraint(:object)
	|> Changeset.assoc_constraint(:relationship)
end
end
