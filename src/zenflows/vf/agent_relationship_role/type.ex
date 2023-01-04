# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.VF.AgentRelationshipRole.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.AgentRelationshipRole.Resolv

@role_behavior """
The general shape or behavior grouping of an agent relationship role.
"""
@role_behavior_id "(`RoleBehavior`) #{@role_behavior}"
@role_label """
The human readable name of the role, from the subject to the object.
"""
@inverse_role_label """
The human readable name of the role, from the object to the subject.
"""
@note "A textual description or comment."

object :agent_relationship_role do
	field :id, non_null(:id)

	@desc @role_behavior
	field :role_behavior, :role_behavior,
		resolve: &Resolv.role_behavior/3

	@desc @role_label
	field :role_label, non_null(:string)

	@desc @inverse_role_label
	field :inverse_role_label, :string

	@desc @note
	field :note, :string
end

input_object :agent_relationship_role_create_params do
	@desc @role_behavior_id
	field :role_behavior_id, :id, name: "role_behavior"

	@desc @role_label
	field :role_label, non_null(:string)

	@desc @inverse_role_label
	field :inverse_role_label, :string

	@desc @note
	field :note, :string
end

input_object :agent_relationship_role_update_params do
	field :id, non_null(:id)

	@desc @role_behavior_id
	field :role_behavior_id, :id, name: "role_behavior"

	@desc @role_label
	field :role_label, :string

	@desc @inverse_role_label
	field :inverse_role_label, :string

	@desc @note
	field :note, :string
end

object :agent_relationship_role_response do
	field :agent_relationship_role, non_null(:agent_relationship_role)
end

object :agent_relationship_role_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:agent_relationship_role)
end

object :agent_relationship_role_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:agent_relationship_role_edge)))
end

object :query_agent_relationship_role do
	@desc "Retrieve details of an agent relationship role by its ID."
	field :agent_relationship_role, :agent_relationship_role do
		arg :id, non_null(:id)
		resolve &Resolv.agent_relationship_role/2
	end

	@desc """
	Retrieve possible kinds of associations that agents may have
	with one another in this collaboration space.
	"""
	field :agent_relationship_roles, :agent_relationship_role_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.agent_relationship_roles/2
	end
end

object :mutation_agent_relationship_role do
	field :create_agent_relationship_role, non_null(:agent_relationship_role_response) do
		arg :agent_relationship_role, non_null(:agent_relationship_role_create_params)
		resolve &Resolv.create_agent_relationship_role/2
	end

	field :update_agent_relationship_role, non_null(:agent_relationship_role_response) do
		arg :agent_relationship_role, non_null(:agent_relationship_role_update_params)
		resolve &Resolv.update_agent_relationship_role/2
	end

	field :delete_agent_relationship_role, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_agent_relationship_role/2
	end
end
end
