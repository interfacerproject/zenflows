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

use Zenflows.DB.Schema

alias Zenflows.File
alias Zenflows.VF.SpatialThing

@type t() :: %__MODULE__{
	# common
	type: :per | :org, # Person or Organization
	name: String.t(),
	note: String.t() | nil,
	images: [File.t()],
	primary_location: SpatialThing.t() | nil,

	# person
	user: String.t() | nil,
	email: String.t() | nil,
	ecdh_public_key: String.t() | nil,
	eddsa_public_key: String.t() | nil,
	ethereum_address: String.t() | nil,
	reflow_public_key: String.t() | nil,
	schnorr_public_key: String.t() | nil,

	# organization
	classified_as: [String.t()] | nil,
}

schema "vf_agent" do
	# common
	field :type, Ecto.Enum, values: [:per, :org]
	field :name, :string
	field :note, :string
	has_many :images, File
	belongs_to :primary_location, SpatialThing
	timestamps()

	# person
	field :user, :string
	field :email, :string
	field :ecdh_public_key, :string
	field :eddsa_public_key, :string
	field :ethereum_address, :string
	field :reflow_public_key, :string
	field :schnorr_public_key, :string

	# organization
	field :classified_as, {:array, :string}
end
end
