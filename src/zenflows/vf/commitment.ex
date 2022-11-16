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

defmodule Zenflows.VF.Commitment do
@moduledoc """
A planned economic flow that has been promised by an agent to another
agent.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	Action,
	Agent,
	Agreement,
	EconomicResource,
	Measure,
	Plan,
	Process,
	ResourceSpecification,
	SpatialThing,
	Unit,
}

@type t() :: %__MODULE__{
	action: Action.t(),
	provider: Agent.t(),
	receiver: Agent.t(),
	input_of: Process.t() | nil,
	output_of: Process.t() | nil,
	resource_classified_as: [String.t()] | nil,
	resource_conforms_to: ResourceSpecification.t() | nil,
	resource_inventoried_as: EconomicResource.t() | nil,
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	has_beginning: DateTime.t() | nil,
	has_end: DateTime.t() | nil,
	has_point_in_time: DateTime.t() | nil,
	due: DateTime.t() | nil,
	finished: boolean(),
	note: String.t() | nil,
	# in_scope_of:
	agreed_in: String.t() | nil,
	independent_demand_of: Plan.t() | nil,
	at_location: SpatialThing.t() | nil,
	clause_of: Agreement.t() | nil,
}

schema "vf_commitment" do
	field :action_id, Action.ID
	field :action, :map, virtual: true
	belongs_to :provider, Agent
	belongs_to :receiver, Agent
	belongs_to :input_of, Process
	belongs_to :output_of, Process
	field :resource_classified_as, {:array, :string}
	belongs_to :resource_conforms_to, ResourceSpecification
	belongs_to :resource_inventoried_as, EconomicResource
	field :resource_quantity, :map, virtual: true
	belongs_to :resource_quantity_has_unit, Unit
	field :resource_quantity_has_numerical_value, :decimal
	field :effort_quantity, :map, virtual: true
	belongs_to :effort_quantity_has_unit, Unit
	field :effort_quantity_has_numerical_value, :decimal
	field :has_beginning, :utc_datetime_usec
	field :has_end, :utc_datetime_usec
	field :has_point_in_time, :utc_datetime_usec
	field :due, :utc_datetime_usec
	field :finished, :boolean, default: false
	field :note, :string
	# field :in_scope_of
	field :agreed_in, :string
	belongs_to :independent_demand_of, Plan
	belongs_to :at_location, SpatialThing
	belongs_to :clause_of, Agreement
	timestamps()
end

@reqr ~w[action_id provider_id receiver_id]a
@cast @reqr ++ ~w[
	input_of_id output_of_id resource_classified_as
	resource_conforms_to_id resource_inventoried_as_id
	resource_quantity effort_quantity
	has_beginning has_end has_point_in_time due
	finished note agreed_in
	independent_demand_of_id at_location_id clause_of_id
]a # in_scope_of_id

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.exist_or([:has_point_in_time, :has_beginning, :has_end, :due])
	|> Validate.exist_nand([:has_point_in_time, :has_beginning])
	|> Validate.exist_nand([:has_point_in_time, :has_end])
	|> Validate.exist_xor([:resource_conforms_to_id, :resource_inventoried_as_id], method: :both)
	|> Validate.note(:note)
	|> Validate.class(:resource_classified_as)
	|> Measure.cast(:effort_quantity)
	|> Measure.cast(:resource_quantity)
	|> Changeset.assoc_constraint(:provider)
	|> Changeset.assoc_constraint(:receiver)
	|> Changeset.assoc_constraint(:input_of)
	|> Changeset.assoc_constraint(:output_of)
	|> Changeset.assoc_constraint(:resource_conforms_to)
	|> Changeset.assoc_constraint(:resource_inventoried_as)
	|> Changeset.assoc_constraint(:independent_demand_of)
	|> Changeset.assoc_constraint(:at_location)
	|> Changeset.assoc_constraint(:clause_of)
end
end
