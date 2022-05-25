defmodule Zenflows.VF.ScenarioDefinition.Type do
@moduledoc "GraphQL types of ScenarioDefinitiones."

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

object :scenario_definition_response do
	field :scenario_definition, non_null(:scenario_definition)
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

object :query_scenario_definition do
	field :scenario_definition, :scenario_definition do
		arg :id, non_null(:id)
		resolve &Resolv.scenario_definition/2
	end

	#scenarioDefinitions(start: ID, limit: Int): [ScenarioDefinition!]
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
