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

defmodule Zenflows.VF.ScenarioDefinition do
@moduledoc """
The type definition of one or more scenarios, such as Yearly Budget.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Duration,
	TimeUnitEnum,
}

@type t() :: %__MODULE__{
	name: String.t(),
	note: String.t() | nil,
	has_duration_unit_type: TimeUnitEnum.t() | nil,
	has_duration_numeric_duration: Decimal.t() | nil,
	has_duration: Duration.t() | nil,
}

schema "vf_scenario_definition" do
	field :name, :string
	field :note, :string
	field :has_duration, :map, virtual: true
	field :has_duration_unit_type, TimeUnitEnum
	field :has_duration_numeric_duration, :decimal
	timestamps()
end

@reqr [:name]
@cast @reqr ++ ~w[note has_duration]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	Changeset.cast(schema, params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Duration.cast(:has_duration)
end
end
