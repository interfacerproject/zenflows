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

defmodule Zenflows.VF.Settlement do
@moduledoc """
Represents many-to-many relationships between claim and economic events
that fully or partially settle one or more claims.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Claim,
	EconomicEvent,
	Measure,
	Unit,
}

@type t() :: %__MODULE__{
	settled_by: EconomicEvent.t(),
	settles: Claim.t(),
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	note: String.t() | nil,
}

schema "vf_settlement" do
	belongs_to :settled_by, EconomicEvent
	belongs_to :settles, Claim
	field :resource_quantity, :map, virtual: true
	belongs_to :resource_quantity_has_unit, Unit
	field :resource_quantity_has_numerical_value, :decimal
	field :effort_quantity, :map, virtual: true
	belongs_to :effort_quantity_has_unit, Unit
	field :effort_quantity_has_numerical_value, :decimal
	field :note, :string
	timestamps()
end

@reqr ~w[settled_by_id settles_id]a
@cast @reqr ++ ~w[resource_quantity effort_quantity note]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Measure.cast(:resource_quantity)
	|> Measure.cast(:effort_quantity)
	|> Changeset.assoc_constraint(:settled_by)
	|> Changeset.assoc_constraint(:settles)
end
end
