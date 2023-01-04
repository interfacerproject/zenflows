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

defmodule Zenflows.VF.ScenarioDefinition.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.ScenarioDefinition.Resolv

@name """
An informal or formal textual identifier for a scenario definition.
Does not imply uniqueness.
"""
@note "A textual description or comment."
@has_duration """
The planned calendar duration of the process as defined for the recipe
batch.
"""

@desc "The type definition of one or more scenarios, such as Yearly Budget."
object :scenario_definition do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @has_duration
	field :has_duration, :duration, resolve: &Resolv.has_duration/3

	@desc @note
	field :note, :string
end

input_object :scenario_definition_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @has_duration
	field :has_duration, :iduration
end

input_object :scenario_definition_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @has_duration
	field :has_duration, :iduration
end

object :scenario_definition_response do
	field :scenario_definition, non_null(:scenario_definition)
end

object :scenario_definition_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:scenario_definition)
end

object :scenario_definition_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:scenario_definition_edge)))
end

object :query_scenario_definition do
	field :scenario_definition, :scenario_definition do
		arg :id, non_null(:id)
		resolve &Resolv.scenario_definition/2
	end

	field :scenario_definitions, :scenario_definition_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.scenario_definitions/2
	end
end

object :mutation_scenario_definition do
	field :create_scenario_definition, non_null(:scenario_definition_response) do
		arg :scenario_definition, non_null(:scenario_definition_create_params)
		resolve &Resolv.create_scenario_definition/2
	end

	field :update_scenario_definition, non_null(:scenario_definition_response) do
		arg :scenario_definition, non_null(:scenario_definition_update_params)
		resolve &Resolv.update_scenario_definition/2
	end

	field :delete_scenario_definition, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_scenario_definition/2
	end
end
end
