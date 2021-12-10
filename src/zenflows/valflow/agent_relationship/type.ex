defmodule Zenflows.Valflow.AgentRelationship.Type do
@moduledoc "GraphQL types of AgentRelationships."

use Absinthe.Schema.Notation

alias Zenflows.Valflow.AgentRelationship.Resolv

@subject """
The subject of a relationship between two agents.  For example, if Mary
is a member of a group, then Mary is the subject.
"""
@object """
The object of a relationship between two agents.  For example, if Mary
is a member of a group, then the group is the object.
"""
@relationship "A kind of relationship that exists between two agents."
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

object :agent_relationship_response do
	field :agent_relationship, non_null(:agent_relationship)
end

input_object :agent_relationship_create_params do
	@desc "(`Agent`) " <> @subject
	field :subject_id, non_null(:id), name: "subject"

	@desc "(`Agent`) " <> @object
	field :object_id, non_null(:id), name: "object"

	@desc "(`AgentRelationshipRole`) " <> @relationship
	field :relationship_id, non_null(:id), name: "relationship"

	#@desc @in_scope_of
	#field :in_scope_of, list_of(non_null(:accounting_scope))

	@desc @note
	field :note, :string
end

input_object :agent_relationship_update_params do
	field :id, non_null(:id)

	@desc "(`Agent`) " <> @subject
	field :subject_id, :id, name: "subject"

	@desc "(`Agent`) " <> @object
	field :object_id, :id, name: "object"

	@desc "(`AgentRelationshipRole`) " <> @relationship
	field :relationship_id, :id, name: "relationship"

	#@desc @in_scope_of
	#field :in_scope_of, list_of(non_null(:accounting_scope))

	@desc @note
	field :note, :string
end

object :query_agent_relationship do
	@desc "Retrieve details of an agent relationship by its ID."
	field :agent_relationship, :agent_relationship do
		arg :id, non_null(:id)
		resolve &Resolv.agent_relationship/2
	end

	#@desc """
	#Retrieve details of all the relationships between all agents
	#registered in this collaboration space.
	#"""
	#agentRelationships(start: ID, limit: Int): [AgentRelationship!]
end

object :mutation_agent_relationship do
	field :create_agent_relationship, :agent_relationship_response do
		arg :relationship, non_null(:agent_relationship_create_params)
		resolve &Resolv.create_agent_relationship/2
	end

	field :update_agent_relationship, :agent_relationship_response do
		arg :relationship, non_null(:agent_relationship_update_params)
		resolve &Resolv.update_agent_relationship/2
	end

	field :delete_agent_relationship, :boolean do
		arg :id, non_null(:id)
		resolve &Resolv.delete_agent_relationship/2
	end
end
end
