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

defmodule Zenflows.VF.Scenario do
@moduledoc """
An estimated or analytical logical collection of higher level processes
used for budgeting, analysis, plan refinement, etc.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Scenario,
	ScenarioDefinition,
}

@type t() :: %__MODULE__{
	name: String.t(),
	note: String.t() | nil,
	has_beginning: DateTime.t() | nil,
	has_end: DateTime.t() | nil,
	defined_as: ScenarioDefinition.t() | nil,
	refinement_of: Scenario.t() | nil,
}

schema "vf_scenario" do
	field :name, :string
	field :note, :string
	field :has_beginning, :utc_datetime_usec
	field :has_end, :utc_datetime_usec
	# field :in_scope_of
	belongs_to :defined_as, ScenarioDefinition
	belongs_to :refinement_of, Scenario
	timestamps()
end

@reqr [:name]
@cast @reqr ++ ~w[
	note
	has_beginning has_end
	defined_as_id refinement_of_id
]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:defined_as)
	|> Changeset.assoc_constraint(:refinement_of)
end
end
