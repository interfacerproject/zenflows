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

defmodule Zenflows.VF.Plan.Type do
@moduledoc "GraphQL types of Plans."

use Absinthe.Schema.Notation

alias Zenflows.VF.Plan.Resolv

@name """
An informal or formal textual identifier for a plan.  Does not imply
uniqueness.
"""
@note "A textual description or comment."
@created "The time the plan was made."
@due "The time the plan is expected to be complete."
@deletable "The plan is able to be deleted or not."
@refinement_of "This plan refines a scenario, making it operational."

@desc """
A logical collection of processes that constitute a body of planned work
with defined deliverable(s).
"""
object :plan do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @created
	field :inserted_at, non_null(:datetime), name: "created"

	@desc @due
	field :due, :datetime

	@desc @deletable
	field :deletable, non_null(:boolean)

	@desc @refinement_of
	field :refinement_of, :scenario, resolve: &Resolv.refinement_of/3
end

object :plan_response do
	field :plan, non_null(:plan)
end

input_object :plan_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @due
	field :due, :datetime

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`Scenario`) " <> @refinement_of
	field :refinement_of_id, :id, name: "refinement_of"
end

input_object :plan_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @due
	field :due, :datetime

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`Scenario`) " <> @refinement_of
	field :refinement_of_id, :id, name: "refinement_of"
end

object :query_plan do
	field :plan, :plan do
		arg :id, non_null(:id)
		resolve &Resolv.plan/2
	end

	#plans(start: ID, limit: Int): [Plan!]
end

object :mutation_plan do
	field :create_plan, non_null(:plan_response) do
		arg :plan, non_null(:plan_create_params)
		resolve &Resolv.create_plan/2
	end

	field :update_plan, non_null(:plan_response) do
		arg :plan, non_null(:plan_update_params)
		resolve &Resolv.update_plan/2
	end

	field :delete_plan, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_plan/2
	end
end
end
