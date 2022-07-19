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

defmodule Zenflows.VF.Proposal do
@moduledoc """
Published requests or offers, sometimes with what is expected in return.
"""

use Zenflows.DB.Schema

alias Zenflows.VF.{SpatialThing, Validate}

@type t() :: %__MODULE__{
	name: String.t(),
	has_beginning: DateTime.t() | nil,
	has_end: DateTime.t() | nil,
	unit_based: boolean(),
	created: DateTime.t(),
	note: String.t() | nil,
	eligible_location: SpatialThing.t() | nil,
}

schema "vf_proposal" do
	field :name, :string
	field :has_beginning, :utc_datetime_usec
	field :has_end, :utc_datetime_usec
	field :unit_based, :boolean, default: false
	timestamps(inserted_at: :created, updated_at: false)
	field :note, :string
	belongs_to :eligible_location, SpatialThing
end

@cast ~w[name has_beginning has_end unit_based note eligible_location_id]a

@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:eligible_location)
end
end
