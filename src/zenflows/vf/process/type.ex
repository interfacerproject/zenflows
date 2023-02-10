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

defmodule Zenflows.VF.Process.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.Process.Resolv

@name """
An informal or formal textual identifier for a process.  Does not imply
uniqueness.
"""
@note "A textual description or comment."
@has_beginning "The planned beginning of the process."
@has_end "The planned end of the process."
@finished """
The process is complete or not.  This is irrespective of if the original
goal has been met, and indicates that no more will be done.
"""
@deletable """
The process can be safely deleted, has no dependent information.
"""
@classified_as """
References one or more concepts in a common taxonomy or other
classification scheme for purposes of categorization or grouping.
"""
@based_on "The definition or specification for a process."
@based_on_id "(`ProcesssSpecification`) #{@based_on}"
@planned_within """
The process with its inputs and outputs is part of the plan.
"""
@planned_within_id "(`Plan`) #{@planned_within}"
@nested_in """
The process with its inputs and outputs is part of the scenario.
"""
@nested_in_id "(`Scenario`) #{@nested_in}"
@grouped_in """
A ProcessGroup, to which this Process belongs.

It also implies that the ProcessGroup to which this Process belongs
holds nothing but only Processes.
"""
@grouped_in_id "(`ProcessGroup`) #{@grouped_in}"

@desc """
A logical collection of processes that constitute a body of processned work
with defined deliverable(s).
"""
object :process do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @finished
	field :finished, non_null(:boolean)

	@desc @deletable
	field :deletable, non_null(:boolean)

	@desc @classified_as
	field :classified_as, list_of(non_null(:uri))

	@desc @based_on
	field :based_on, :process_specification,
		resolve: &Resolv.based_on/3

	@desc @planned_within
	field :planned_within, :plan,
		resolve: &Resolv.planned_within/3

	@desc @nested_in
	field :nested_in, :scenario, resolve: &Resolv.nested_in/3

	field :previous, list_of(non_null(:economic_event)),
		resolve: &Resolv.previous/3

	@desc @grouped_in
	field :grouped_in, :process_group, resolve: &Resolv.grouped_in/3
end

input_object :process_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @finished
	field :finished, :boolean

	@desc @classified_as
	field :classified_as, list_of(non_null(:uri))

	@desc @based_on_id
	field :based_on_id, :id, name: "based_on"

	@desc @planned_within_id
	field :planned_within_id, :id, name: "planned_within"

	@desc @nested_in_id
	field :nested_in_id, :id, name: "nested_in"

	@desc @grouped_in_id
	field :grouped_in_id, :id, name: "grouped_in"
end

input_object :process_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @finished
	field :finished, :boolean

	@desc @classified_as
	field :classified_as, list_of(non_null(:uri))

	@desc @based_on_id
	field :based_on_id, :id, name: "based_on"

	@desc @planned_within_id
	field :planned_within_id, :id, name: "planned_within"

	@desc @nested_in_id
	field :nested_in_id, :id, name: "nested_in"

	@desc @grouped_in_id
	field :grouped_in_id, :id, name: "grouped_in"
end

object :process_response do
	field :process, non_null(:process)
end

object :process_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:process)
end

object :process_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:process_edge)))
end

object :query_process do
	field :process, :process do
		arg :id, non_null(:id)
		resolve &Resolv.process/2
	end

	field :processes, :process_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.processes/2
	end
end

object :mutation_process do
	field :create_process, non_null(:process_response) do
		arg :process, non_null(:process_create_params)
		resolve &Resolv.create_process/2
	end

	field :update_process, non_null(:process_response) do
		arg :process, non_null(:process_update_params)
		resolve &Resolv.update_process/2
	end

	field :delete_process, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_process/2
	end
end
end
