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

defmodule Zenflows.VF.Organization do
@moduledoc "A formal or informal group, or legal organization."

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.SpatialThing

@type t() :: %__MODULE__{
	type: :org,
	name: String.t(),
	images: [map()],
	note: String.t() | nil,
	primary_location: SpatialThing.t() | nil,
	classified_as: [String.t()] | nil,
	updated_at: DateTime.t(),
	is_verified: boolean(),
}

schema "vf_agent" do
	field :type, Ecto.Enum, values: [:org], default: :org
	field :name, :string
	field :images, {:array, :map}, virtual: true
	field :note, :string
	belongs_to :primary_location, SpatialThing
	field :classified_as, {:array, :string}
	field :is_verified, :boolean, default: false
	timestamps()
end

@reqr [:name]
@cast @reqr ++ ~w[classified_as note primary_location_id images is_verified]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.class(:classified_as)
	|> Changeset.assoc_constraint(:primary_location)
end
end
