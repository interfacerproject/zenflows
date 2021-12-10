defmodule Zenflows.Valflow.RecipeFlow do
@moduledoc """
The specification of a resource inflow to, or outflow from, a recipe process.
"""

use Zenflows.Ecto.Schema

alias Zenflows.Valflow.{
	ActionEnum,
	Measure,
	RecipeExchange,
	RecipeProcess,
	RecipeResource,
	Validate,
}

@type t() :: %__MODULE__{
	action: ActionEnum.t(),
	recipe_input_of: RecipeProcess.t() | nil,
	recipe_output_of: RecipeProcess.t() | nil,
	recipe_flow_resource: RecipeResource.t() | nil,
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	recipe_clause_of: RecipeExchange.t() | nil,
	note: String.t() | nil,
}

schema "vf_recipe_flow" do
	field :action, ActionEnum
	belongs_to :recipe_input_of, RecipeProcess
	belongs_to :recipe_output_of, RecipeProcess
	belongs_to :recipe_flow_resource, RecipeResource
	belongs_to :resource_quantity, Measure
	belongs_to :effort_quantity, Measure
	belongs_to :recipe_clause_of, RecipeExchange
	field :note, :string
end

@reqr [:action]
@cast @reqr ++ ~w[
	recipe_input_of_id recipe_output_of_id recipe_flow_resource_id
	resource_quantity_id effort_quantity_id recipe_clause_of_id
	note
]a

@doc false
@spec chset(Schema.t(), params()) :: Changeset.t()
def chset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:recipe_input_of)
	|> Changeset.assoc_constraint(:recipe_output_of)
	|> Changeset.assoc_constraint(:recipe_flow_resource)
	|> Changeset.assoc_constraint(:resource_quantity)
	|> Changeset.assoc_constraint(:effort_quantity)
	|> Changeset.assoc_constraint(:recipe_clause_of)
end
end
