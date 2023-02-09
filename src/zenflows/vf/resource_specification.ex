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

defmodule Zenflows.VF.ResourceSpecification do
@moduledoc """
Specification of a kind of resource.  Could define a material item,
service, digital item, currency account, etc.  Used instead of a
classification when more information is needed, particularly for recipes.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.File
alias Zenflows.VF.Unit

@type t() :: %__MODULE__{
	name: String.t(),
	images: [File.t()],
	resource_classified_as: [String.t()] | nil,
	note: String.t() | nil,
	default_unit_of_effort: Unit.t() | nil,
	default_unit_of_resource: Unit.t() | nil,
}

schema "vf_resource_specification" do
	field :name, :string
	has_many :images, File
	field :resource_classified_as, {:array, :string}
	field :note, :string
	belongs_to :default_unit_of_resource, Unit
	belongs_to :default_unit_of_effort, Unit
	timestamps()
end

@reqr [:name]
@cast @reqr ++ ~w[
	resource_classified_as note
	default_unit_of_effort_id
	default_unit_of_resource_id
]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Changeset.cast_assoc(:images)
	|> Validate.class(:resource_classified_as)
	|> Changeset.assoc_constraint(:default_unit_of_resource)
	|> Changeset.assoc_constraint(:default_unit_of_effort)
end
end
