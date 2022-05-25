defmodule Zenflows.VF.AgentRelationshipRole do
@moduledoc """
The role of an economic relationship that exists between two agents,
such as member, trading partner.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{RoleBehavior, Validate}

@type t() :: %__MODULE__{
	role_behavior: RoleBehavior.t() | nil,
	role_label: String.t(),
	inverse_role_label: String.t() | nil,
	note: String.t() | nil,
}

schema "vf_agent_relationship_role" do
	belongs_to :role_behavior, RoleBehavior
	field :role_label, :string
	field :inverse_role_label, :string
	field :note, :string
end

@reqr [:role_label]
@cast @reqr ++ ~w[role_behavior_id inverse_role_label note]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:role_label)
	|> Validate.name(:inverse_role_label)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:role_behavior)
end
end
