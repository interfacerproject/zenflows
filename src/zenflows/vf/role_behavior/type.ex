# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.RoleBehavior.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.RoleBehavior.Resolv

@name """
An informal or formal textual identifier for a role behavior.  Does not
imply uniqueness.
"""
@note "A textual description or comment."

@desc """
The general shape or behavior grouping of an agent relationship role.
"""
object :role_behavior do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

input_object :role_behavior_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

input_object :role_behavior_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string
end

object :role_behavior_response do
	field :role_behavior, non_null(:role_behavior)
end

object :role_behavior_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:role_behavior)
end

object :role_behavior_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:role_behavior_edge)))
end

object :query_role_behavior do
	field :role_behavior, :role_behavior do
		arg :id, non_null(:id)
		resolve &Resolv.role_behavior/2
	end

	field :role_behaviors, :role_behavior_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.role_behaviors/2
	end
end

object :mutation_role_behavior do
	@desc "Creates a role behavior."
	field :create_role_behavior, non_null(:role_behavior_response) do
		arg :role_behavior, non_null(:role_behavior_create_params)
		resolve &Resolv.create_role_behavior/2
	end

	@desc "Updates a role behavior."
	field :update_role_behavior, non_null(:role_behavior_response) do
		arg :role_behavior, non_null(:role_behavior_update_params)
		resolve &Resolv.update_role_behavior/2
	end

	@desc "Deletes a role behavior."
	field :delete_role_behavior, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_role_behavior/2
	end
end
end
