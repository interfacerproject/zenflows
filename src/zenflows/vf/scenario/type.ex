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

defmodule Zenflows.VF.Scenario.Type do
@moduledoc "GraphQL types of Scenarios."

use Absinthe.Schema.Notation

alias Zenflows.VF.Scenario.Resolv

@name """
An informal or formal textual identifier for a scenario.  Does not
imply uniqueness.
"""
@note "A textual description or comment."
@has_beginning """
The beginning date/time of the scenario, often the beginning of an
accounting period.
"""
@has_end """
The ending date/time of the scenario, often the end of an accounting
period.
"""
@defined_as """
The scenario definition for this scenario, for example yearly budget.
"""
@refinement_of """
This scenario refines another scenario, often as time moves closer or
for more detail.
"""

@desc """
An estimated or analytical logical collection of higher level processes
used for budgeting, analysis, plan refinement, etc."
"""
object :scenario do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	@desc @defined_as
	field :defined_as, :scenario_definition,
		resolve: &Resolv.defined_as/3

	@desc @refinement_of
	field :refinement_of, :scenario, resolve: &Resolv.refinement_of/3
end

object :scenario_response do
	field :scenario, non_null(:scenario)
end

input_object :scenario_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`ScenarioDefinition`) " <> @defined_as
	field :defined_as_id, :id, name: "defined_as"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`Scenario`) " <> @refinement_of
	field :refinement_of_id, :id, name: "refinement_of"
end

input_object :scenario_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @has_beginning
	field :has_beginning, :datetime

	@desc @has_end
	field :has_end, :datetime

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`ScenarioDefinition`) " <> @defined_as
	field :defined_as_id, :id, name: "defined_as"

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`Scenario`) " <> @refinement_of
	field :refinement_of_id, :id, name: "refinement_of"
end

object :query_scenario do
	field :scenario, :scenario do
		arg :id, non_null(:id)
		resolve &Resolv.scenario/2
	end

	#scenarioDefinitions(start: ID, limit: Int): [Scenario!]
end

object :mutation_scenario do
	field :create_scenario, non_null(:scenario_response) do
		arg :scenario, non_null(:scenario_create_params)
		resolve &Resolv.create_scenario/2
	end

	field :update_scenario, non_null(:scenario_response) do
		arg :scenario, non_null(:scenario_update_params)
		resolve &Resolv.update_scenario/2
	end

	field :delete_scenario, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_scenario/2
	end
end
end
