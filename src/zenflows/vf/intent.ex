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

defmodule Zenflows.VF.Intent do
@moduledoc """
A planned economic flow which has not been committed to, which can lead
to economic events (sometimes through commitments).
"""
use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.File
alias Zenflows.VF.{
	Action,
	Agent,
	EconomicResource,
	Measure,
	Process,
	ProposedIntent,
	ResourceSpecification,
	SpatialThing,
	Unit,
}

@type t() :: %__MODULE__{
	name: String.t() | nil,
	action: Action.t(),
	provider: Agent.t() | nil,
	receiver: Agent.t() | nil,
	input_of: Process.t() | nil,
	output_of: Process.t() | nil,
	resource_classified_as: [String.t()] | nil,
	resource_conforms_to: ResourceSpecification.t() | nil,
	resource_inventoried_as: EconomicResource.t() | nil,
	resource_quantity: Measure.t() | nil,
	effort_quantity: Measure.t() | nil,
	available_quantity: Measure.t() | nil,
	at_location: SpatialThing.t() | nil,
	has_beginning: DateTime.t() | nil,
	has_end: DateTime.t() | nil,
	has_point_in_time: DateTime.t() | nil,
	due: DateTime.t() | nil,
	finished: boolean(),
	images: [File.t()],
	note: String.t() | nil,
	# in_scope_of:
	agreed_in: String.t() | nil,

	published_in: [ProposedIntent.t()],
}

schema "vf_intent" do
	field :name
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
	field :available_quantity, :map, virtual: true
	belongs_to :available_quantity_has_unit, Unit
	field :available_quantity_has_numerical_value, :decimal
	belongs_to :at_location, SpatialThing
	field :has_beginning, :utc_datetime_usec
	field :has_end, :utc_datetime_usec
	field :has_point_in_time, :utc_datetime_usec
	field :due, :utc_datetime_usec
	field :finished, :boolean, default: false
	has_many :images, File
	field :note, :string
	# field :in_scope_of
	field :agreed_in, :string
	timestamps()

	has_many :published_in, ProposedIntent, foreign_key: :publishes_id
end

@reqr [:action_id]
@cast @reqr ++ ~w[
	name provider_id receiver_id input_of_id output_of_id
	resource_classified_as resource_conforms_to_id resource_inventoried_as_id
	resource_quantity effort_quantity available_quantity
	at_location_id has_beginning has_end has_point_in_time due
	finished note agreed_in
]a # in_scope_of_id

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.exist_xor([:provider_id, :receiver_id], method: :both)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Changeset.cast_assoc(:images)
	|> Validate.class(:resource_classified_as)
	|> Measure.cast(:resource_quantity)
	|> Measure.cast(:effort_quantity)
	|> Measure.cast(:available_quantity)
	|> Changeset.assoc_constraint(:provider)
	|> Changeset.assoc_constraint(:receiver)
	|> Changeset.assoc_constraint(:input_of)
	|> Changeset.assoc_constraint(:output_of)
	|> Changeset.assoc_constraint(:resource_conforms_to)
	|> Changeset.assoc_constraint(:resource_inventoried_as)
	|> Changeset.assoc_constraint(:at_location)
end
end
