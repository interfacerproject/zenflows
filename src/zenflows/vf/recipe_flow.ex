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

defmodule Zenflows.VF.RecipeFlow do
@moduledoc """
The specification of a resource inflow to, or outflow from, a recipe process.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{
	Action,
	Measure,
	RecipeExchange,
	RecipeProcess,
	RecipeResource,
	Unit,
	Validate,
}

@type t() :: %__MODULE__{
	action: Action.t(),
	recipe_input_of: RecipeProcess.t() | nil,
	recipe_output_of: RecipeProcess.t() | nil,
	recipe_flow_resource: RecipeResource.t() | nil,
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	recipe_clause_of: RecipeExchange.t() | nil,
	note: String.t() | nil,
}

schema "vf_recipe_flow" do
	field :note, :string
	field :action_id, Action.ID
	field :action, :map, virtual: true
	belongs_to :recipe_input_of, RecipeProcess
	belongs_to :recipe_output_of, RecipeProcess
	belongs_to :recipe_flow_resource, RecipeResource
	field :resource_quantity, :map, virtual: true
	belongs_to :resource_quantity_has_unit, Unit
	field :resource_quantity_has_numerical_value, :float
	field :effort_quantity, :map, virtual: true
	belongs_to :effort_quantity_has_unit, Unit
	field :effort_quantity_has_numerical_value, :float
	belongs_to :recipe_clause_of, RecipeExchange
	timestamps()
end

@reqr ~w[action_id recipe_flow_resource_id]a
@cast @reqr ++ ~w[
	recipe_input_of_id recipe_output_of_id
	resource_quantity effort_quantity
	recipe_clause_of_id note
]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Measure.cast(:effort_quantity)
	|> Measure.cast(:resource_quantity)
	|> check_measures()
	|> Changeset.assoc_constraint(:recipe_input_of)
	|> Changeset.assoc_constraint(:recipe_output_of)
	|> Changeset.assoc_constraint(:recipe_flow_resource)
end

# Validates that the DB doesn't end up with null measures, meaning either
# one must be filled.
@spec check_measures(Changeset.t()) :: Changeset.t()
defp check_measures(cset) do
	# `*_has_numerical_value` fields not nil when `*_has_unit_id`
	# fields are not nil.  This is guranteed by the `Measure.cast/2`
	# functions.
	resqty = Changeset.get_field(cset, :resource_quantity_has_unit_id)
	effqty = Changeset.get_field(cset, :effort_quantity_has_unit_id)

	if resqty || effqty do
		cset
	else
		msg = "resource quantity and effort quantity cannot be null at the same time"

		cset
		|> Changeset.add_error(:resource_quantity, msg)
		|> Changeset.add_error(:effort_quantity, msg)
	end
end
end
