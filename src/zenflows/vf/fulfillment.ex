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

defmodule Zenflows.VF.Fulfillment do
@moduledoc """
Represents many-to-many relationships between commitments and economic
events that fully or partially satisfy one or more commitments.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{
	Commitment,
	EconomicEvent,
	Measure,
	Unit,
	Validate,
}

@type t() :: %__MODULE__{
	note: String.t() | nil,
	fulfilled_by: EconomicEvent.t(),
	fulfills: Commitment.t(),
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
}

schema "vf_fulfillment" do
	field :note, :string
	belongs_to :fulfilled_by, EconomicEvent
	belongs_to :fulfills, Commitment
	field :resource_quantity, :map, virtual: true
	belongs_to :resource_quantity_has_unit, Unit
	field :resource_quantity_has_numerical_value, :float
	field :effort_quantity, :map, virtual: true
	belongs_to :effort_quantity_has_unit, Unit
	field :effort_quantity_has_numerical_value, :float
	timestamps()
end

@reqr ~w[fulfilled_by_id fulfills_id]a
@cast @reqr ++ ~w[resource_quantity effort_quantity note]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Measure.cast(:resource_quantity)
	|> Measure.cast(:effort_quantity)
	|> Changeset.assoc_constraint(:fulfilled_by)
	|> Changeset.assoc_constraint(:fulfills)
end
end
