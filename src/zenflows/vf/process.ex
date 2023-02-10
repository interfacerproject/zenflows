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

defmodule Zenflows.VF.Process do
@moduledoc """
An activity that changes inputs into outputs.  It could transform or
transport economic resource(s).
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{
	EconomicEvent,
	Plan,
	ProcessGroup,
	ProcessSpecification,
	Scenario,
}

@type t() :: %__MODULE__{
	name: String.t(),
	note: nil | String.t(),
	has_beginning: nil | DateTime.t(),
	has_end: nil | DateTime.t(),
	finished: boolean(),
	deletable: boolean(),
	classified_as: [String.t()],
	based_on: nil | ProcessSpecification.t(),
	planned_within: nil | Plan.t(),
	nested_in: nil | Scenario.t(),
	grouped_in: nil | ProcessGroup.t(),
}

@derive {Jason.Encoder, only: ~w[
	id
	name note
	has_beginning has_end
	finished deletable
	classified_as
	based_on_id planned_within_id grouped_in_id
]a}
schema "vf_process" do
	field :name, :string
	field :note, :string
	field :has_beginning, :utc_datetime_usec
	field :has_end, :utc_datetime_usec
	field :finished, :boolean, default: false
	field :deletable, :boolean, default: false, virtual: true
	field :classified_as, {:array, :string}
	belongs_to :based_on, ProcessSpecification
	# belongs_to :in_scope_of
	belongs_to :planned_within, Plan
	belongs_to :nested_in, Scenario
	belongs_to :grouped_in, ProcessGroup
	timestamps()

	has_many :inputs, EconomicEvent, foreign_key: :input_of_id
	has_many :outputs, EconomicEvent, foreign_key: :output_of_id
end

@reqr [:name]
@cast @reqr ++ ~w[
	has_beginning has_end
	finished note classified_as
	based_on_id planned_within_id nested_in_id grouped_in_id
]a # in_scope_of_id

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.class(:classified_as)
	|> Changeset.assoc_constraint(:based_on)
	#|> Changeset.assoc_constraint(:in_scope_of)
	|> Changeset.assoc_constraint(:planned_within)
	|> Changeset.assoc_constraint(:nested_in)
	|> Changeset.assoc_constraint(:grouped_in)
end
end
