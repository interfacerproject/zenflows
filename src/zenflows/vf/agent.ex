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

defmodule Zenflows.VF.Agent do
@moduledoc """
A person or group or organization with economic agency.
"""

use Zenflows.DB.Schema, types?: false

alias Zenflows.VF.SpatialThing

@type t() :: %__MODULE__{
	# common
	type: :per | :org, # Person or Organization
	name: String.t(),
	note: String.t() | nil,
	image: String.t() | nil,
	primary_location: SpatialThing.t() | nil,

	# person
	user: String.t() | nil,
	email: String.t() | nil,
	pubkeys: binary() | nil,

	# organization
	classified_as: [String.t()] | nil,
}

schema "vf_agent" do
	# common
	field :type, Ecto.Enum, values: [:per, :org]
	field :name, :string
	field :note, :string
	field :image, :string, virtual: true
	belongs_to :primary_location, SpatialThing

	# person
	field :user, :string
	field :email, :string
	field :pubkeys, :binary

	# organization
	field :classified_as, {:array, :string}
end
end
