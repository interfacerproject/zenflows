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

defmodule Zenflows.VF.SpatialThing do
@moduledoc """
A physical mappable location.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}

@type t() :: %__MODULE__{
	id: String.t(),
	name: String.t(),
	mappable_address: String.t() | nil,
	lat: Decimal.t() | nil,
	long: Decimal.t() | nil,
	alt: Decimal.t() | nil,
	note: String.t() | nil,
}

@reqr [:name]
@cast @reqr ++ ~w[mappable_address lat long alt note]a

schema "vf_spatial_thing" do
	field :name, :string
	field :mappable_address, :string
	field :lat, :decimal
	field :long, :decimal
	field :alt, :decimal
	field :note, :string
	timestamps()
end

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:name)
	|> Validate.note(:note)
	|> Validate.note(:mappable_address)
end
end
