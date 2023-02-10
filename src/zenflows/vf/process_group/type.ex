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

defmodule Zenflows.VF.ProcessGroup.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.{
	Process,
	ProcessGroup,
	ProcessGroup.Resolv,
}

@name """
An informal or formal textual identifier for a process group.  Does
not imply uniqueness.
"""
@note "A textual description or comment."
@grouped_in """
A ProcessGroup, to which this ProcessGroup belongs.

It also implies that the ProcessGroup to which this ProcessGroup
belongs holds nothing but only ProcessGroups.

A ProcessGroup cannot be in the group of itself.
"""
@grouped_in_id "(`ProcessGroup`) #{@grouped_in}"
@groups """
The Processes xor ProgessGroups which this ProcessGroup groups
(holds/contains).

The resolved data can only be Processes XOR ProcessGroups.
"""

union :process_or_process_group do
	types [:process, :process_group]
	resolve_type fn
		%Process{}, _ -> :process
		%ProcessGroup{}, _ -> :process_group
	end
end

object :process_or_process_group_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:process_or_process_group)
end

object :process_or_process_group_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:process_or_process_group_edge)))
end

@desc """
A filesystem-like structure to hold a group of Processes.
"""
object :process_group do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @grouped_in
	field :grouped_in, :process_group,
		resolve: &Resolv.grouped_in/3

	@desc @groups
	field :groups, :process_or_process_group_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.groups/3
	end
end

input_object :process_group_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @grouped_in_id
	field :grouped_in_id, :id, name: "grouped_in"
end

input_object :process_group_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @grouped_in_id
	field :grouped_in_id, :id, name: "grouped_in"
end

object :process_group_response do
	field :process_group, non_null(:process_group)
end

object :process_group_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:process_group)
end

object :process_group_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:process_group_edge)))
end

object :query_process_group do
	field :process_group, :process_group do
		arg :id, non_null(:id)
		resolve &Resolv.process_group/2
	end

	field :process_groups, :process_group_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.process_groups/2
	end
end

object :mutation_process_group do
	field :create_process_group, non_null(:process_group_response) do
		arg :process_group, non_null(:process_group_create_params)
		resolve &Resolv.create_process_group/2
	end

	field :update_process_group, non_null(:process_group_response) do
		arg :process_group, non_null(:process_group_update_params)
		resolve &Resolv.update_process_group/2
	end

	field :delete_process_group, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_process_group/2
	end
end
end
