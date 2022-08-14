# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.AgentRelationship do
@moduledoc """
A relationship role defining the kind of association one agent can have
with another.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{
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
	timestamps()
end

@reqr ~w[subject_id object_id relationship_id]a
@cast @reqr ++ [:note] # in_scope_of

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:subject)
	|> Changeset.assoc_constraint(:object)
	|> Changeset.assoc_constraint(:relationship)
end
end
