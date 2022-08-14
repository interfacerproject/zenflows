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

defmodule Zenflows.VF.RecipeResource do
@moduledoc """
Specifies the resource as part of a recipe for use in planning from
recipe.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{
	ResourceSpecification,
	Unit,
	Validate,
}

@type t() :: %__MODULE__{
	name: String.t(),
	unit_of_resource: Unit.t() | nil,
	unit_of_effort: Unit.t() | nil,
	resource_conforms_to: ResourceSpecification.t() | nil,
	substitutable: boolean(),
	image: String.t() | nil,
	note: String.t() | nil,
}

schema "vf_recipe_resource" do
	field :name, :string
	belongs_to :unit_of_resource, Unit
	belongs_to :unit_of_effort, Unit
	field :resource_classified_as, {:array, :string}
	belongs_to :resource_conforms_to, ResourceSpecification
	field :substitutable, :boolean, default: false
	field :image, :string
	field :note, :string
	timestamps()
end

@reqr [:name]
@cast @reqr ++ ~w[
	unit_of_resource_id unit_of_effort_id
	resource_classified_as resource_conforms_to_id
	substitutable image note
]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.img(:image)
	|> Validate.class(:resource_conforms_to)
	|> Changeset.assoc_constraint(:unit_of_resource)
	|> Changeset.assoc_constraint(:unit_of_effort)
	|> Changeset.assoc_constraint(:resource_conforms_to)
end
end
