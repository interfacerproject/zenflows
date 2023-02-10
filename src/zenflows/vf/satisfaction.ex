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

defmodule Zenflows.VF.Satisfaction do
@moduledoc """
Represents many-to-many relationships between intents and commitments
or events that partially or full satisfy one or more intents.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Commitment,
	EconomicEvent,
	Intent,
	Measure,
	Unit,
}

@type t() :: %__MODULE__{
	satisfied_by_event: nil | EconomicEvent.t(),
	satisfied_by_commitment: nil | Commitment.t(),
	satisfies: Intent.t(),
	resource_quantity: nil | Measure.t(),
	effort_quantity: nil | Measure.t(),
	note: nil | String.t(),
}

schema "vf_satisfaction" do
	belongs_to :satisfied_by_event, EconomicEvent
	belongs_to :satisfied_by_commitment, Commitment
	belongs_to :satisfies, Intent
	field :resource_quantity, :map, virtual: true
	belongs_to :resource_quantity_has_unit, Unit
	field :resource_quantity_has_numerical_value, :decimal
	field :effort_quantity, :map, virtual: true
	belongs_to :effort_quantity_has_unit, Unit
	field :effort_quantity_has_numerical_value, :decimal
	field :note, :string
	timestamps()
end

@reqr [:satisfies_id]
@cast @reqr ++ ~w[
	satisfied_by_event_id satisfied_by_commitment_id
	resource_quantity effort_quantity note
]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Measure.cast(:resource_quantity)
	|> Measure.cast(:effort_quantity)
	|> Validate.exist_xor(~w[satisfied_by_event_id satisfied_by_commitment_id]a)
	|> Changeset.assoc_constraint(:satisfied_by_event)
	|> Changeset.assoc_constraint(:satisfied_by_commitment)
	|> Changeset.assoc_constraint(:satisfies)
end
end
