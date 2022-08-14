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

defmodule Zenflows.VF.Plan do
@moduledoc """
A logical collection of processes that constitute a body of planned work
with defined deliverable(s).
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{Scenario, Validate}

@type t() :: %__MODULE__{
	name: String.t(),
	due: DateTime.t() | nil,
	note: String.t() | nil,
	refinement_of: Scenario.t() | nil,
}

schema "vf_plan" do
	field :name, :string
	field :due, :utc_datetime_usec
	field :note, :string
	belongs_to :refinement_of, Scenario
	timestamps()
end

@reqr [:name]
@cast @reqr ++ ~w[due note refinement_of_id]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:refinement_of)
end
end
