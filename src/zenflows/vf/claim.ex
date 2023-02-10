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

defmodule Zenflows.VF.Claim do
@moduledoc """
A claim for a future economic event(s) in reciprocity for an economic
event that already occurred.  For example, a claim for payment for goods
received.
"""
use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Action,
	Agent,
	EconomicEvent,
	Measure,
	ResourceSpecification,
	Unit,
}

@type t() :: %__MODULE__{
	action: Action.t(),
	provider: Agent.t(),
	receiver: Agent.t(),
	resource_classified_as: [String.t()] | nil,
	resource_conforms_to: ResourceSpecification.t() | nil,
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	triggered_by: EconomicEvent.t(),
	due: DateTime.t() | nil,
	finished: boolean(),
	note: String.t() | nil,
	agreed_in: String.t() | nil,
	# in_scope_of:
}

schema "vf_claim" do
	field :action_id, Action.ID
	field :action, :map, virtual: true
	belongs_to :provider, Agent
	belongs_to :receiver, Agent
	field :resource_classified_as, {:array, :string}
	belongs_to :resource_conforms_to, ResourceSpecification
	field :resource_quantity, :map, virtual: true
	belongs_to :resource_quantity_has_unit, Unit
	field :resource_quantity_has_numerical_value, :decimal
	field :effort_quantity, :map, virtual: true
	belongs_to :effort_quantity_has_unit, Unit
	field :effort_quantity_has_numerical_value, :decimal
	belongs_to :triggered_by, EconomicEvent
	field :due, :utc_datetime_usec
	field :finished, :boolean
	field :note, :string
	field :agreed_in, :string
	# field :in_scope_of
	timestamps()
end

@reqr ~w[action_id provider_id receiver_id]a
@cast @reqr ++ ~w[
	resource_classified_as resource_conforms_to_id
	resource_quantity effort_quantity
	triggered_by_id due finished note agreed_in
]a # in_scope_of

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.note(:note)
	|> Validate.class(:resource_classified_as)
	|> Measure.cast(:resource_quantity)
	|> Measure.cast(:effort_quantity)
	|> Changeset.assoc_constraint(:provider)
	|> Changeset.assoc_constraint(:receiver)
	|> Changeset.assoc_constraint(:resource_conforms_to)
	|> Changeset.assoc_constraint(:triggered_by)
end
end
