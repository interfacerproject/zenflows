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

defmodule Zenflows.VF.RecipeProcess do
@moduledoc """
Specifies a process in a recipe for use in planning from recipe.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Duration,
	ProcessSpecification,
	TimeUnitEnum,
}

@type t() :: %__MODULE__{
	name: String.t(),
	note: String.t() | nil,
	process_conforms_to: ProcessSpecification.t() | nil,
	process_classified_as: [String.t()] | nil,
	has_duration: Duration.t() | nil,
	has_duration_unit_type: TimeUnitEnum.t() | nil,
	has_duration_numeric_duration: Decimal.t() | nil,
}

schema "vf_recipe_process" do
	field :name, :string
	field :note, :string
	belongs_to :process_conforms_to, ProcessSpecification
	field :process_classified_as, {:array, :string}
	field :has_duration, :map, virtual: true
	field :has_duration_unit_type, TimeUnitEnum
	field :has_duration_numeric_duration, :decimal
	timestamps()
end

@reqr ~w[name process_conforms_to_id]a
@cast @reqr ++ ~w[process_classified_as note has_duration]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.class(:process_classified_as)
	|> Duration.cast(:has_duration)
	|> Changeset.assoc_constraint(:process_conforms_to)
end
end
