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

defmodule Zenflows.VF.AgentRelationship.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.AgentRelationship.Resolv

@subject """
The subject of a relationship between two agents.  For example, if Mary
is a member of a group, then Mary is the subject.
"""
@subject_id "(`Agent`) #{@subject}"
@object """
The object of a relationship between two agents.  For example, if Mary
is a member of a group, then the group is the object.
"""
@object_id "(`Agent`) #{@object}"
@relationship "A kind of relationship that exists between two agents."
@relationship_id "(`AgentRelationshipRole`) #{@relationship}"
#@in_scope_of """
#Grouping around something to create a boundary or context, used for
#documenting, accounting, planning.
#"""
@note "A textual description or comment."

@desc """
The role of an economic relationship that exists between 2 agents,
such as member, trading partner.
"""
object :agent_relationship do
	field :id, non_null(:id)

	@desc @subject
	field :subject, non_null(:agent), resolve: &Resolv.subject/3

	@desc @object
	field :object, non_null(:agent), resolve: &Resolv.object/3

	@desc @relationship
	field :relationship, non_null(:agent_relationship_role),
		resolve: &Resolv.relationship/3

	#@desc @in_scope_of
	#field :in_scope_of, list_of(non_null(:accounting_scope))

	@desc @note
	field :note, :string
end

input_object :agent_relationship_create_params do
	@desc @subject_id
	field :subject_id, non_null(:id), name: "subject"

	@desc @object_id
	field :object_id, non_null(:id), name: "object"

	@desc @relationship_id
	field :relationship_id, non_null(:id), name: "relationship"

	#@desc @in_scope_of
	#field :in_scope_of, list_of(non_null(:accounting_scope))

	@desc @note
	field :note, :string
end

input_object :agent_relationship_update_params do
	field :id, non_null(:id)

	@desc @subject_id
	field :subject_id, :id, name: "subject"

	@desc @object_id
	field :object_id, :id, name: "object"

	@desc @relationship_id
	field :relationship_id, :id, name: "relationship"

	#@desc @in_scope_of
	#field :in_scope_of, list_of(non_null(:accounting_scope))

	@desc @note
	field :note, :string
end

object :agent_relationship_response do
	field :agent_relationship, non_null(:agent_relationship)
end

object :agent_relationship_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:agent_relationship)
end

object :agent_relationship_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:agent_relationship_edge)))
end

object :query_agent_relationship do
	@desc "Retrieve details of an agent relationship by its ID."
	field :agent_relationship, :agent_relationship do
		arg :id, non_null(:id)
		resolve &Resolv.agent_relationship/2
	end

	@desc """
	Retrieve details of all the relationships between all agents
	registered in this collaboration space.
	"""
	field :agent_relationships, :agent_relationship_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.agent_relationships/2
	end
end

object :mutation_agent_relationship do
	field :create_agent_relationship, non_null(:agent_relationship_response) do
		arg :relationship, non_null(:agent_relationship_create_params)
		resolve &Resolv.create_agent_relationship/2
	end

	field :update_agent_relationship, non_null(:agent_relationship_response) do
		arg :relationship, non_null(:agent_relationship_update_params)
		resolve &Resolv.update_agent_relationship/2
	end

	field :delete_agent_relationship, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_agent_relationship/2
	end
end
end
