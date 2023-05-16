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

defmodule Zenflows.VF.Person do
@moduledoc "A natural person."

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.SpatialThing

@type t() :: %__MODULE__{
	type: :per,
	name: String.t(),
	images: [map()],
	note: String.t() | nil,
	primary_location: SpatialThing.t() | nil,
	classified_as: [String.t()] | nil,
	user: String.t(),
	email: String.t(),
	ecdh_public_key: String.t() | nil,
	eddsa_public_key: String.t() | nil,
	ethereum_address: String.t() | nil,
	reflow_public_key: String.t() | nil,
	bitcoin_public_key: String.t() | nil,
	is_verified: boolean(),
}

schema "vf_agent" do
	field :type, Ecto.Enum, values: [:per], default: :per
	field :name, :string
	field :images, {:array, :map}, virtual: true
	field :note, :string
	belongs_to :primary_location, SpatialThing
	field :classified_as, {:array, :string}
	field :user, :string
	field :email, :string
	field :ecdh_public_key, :string
	field :eddsa_public_key, :string
	field :ethereum_address, :string
	field :reflow_public_key, :string
	field :bitcoin_public_key, :string
	field :is_verified, :boolean, default: false
	timestamps()
end

@insert_reqr ~w[name user email]a
@insert_cast @insert_reqr ++ ~w[
	note primary_location_id
	classified_as
	ecdh_public_key
	eddsa_public_key
	ethereum_address
	reflow_public_key
	bitcoin_public_key
	images
	is_verified
]a
# TODO: Maybe add email to @update_cast as well?
# TODO: Maybe add the pubkeys to @update_cast as well?
@update_cast ~w[
	name note primary_location_id classified_as
	user images is_verified
]a

# insert changeset
@doc false
@spec changeset(Schema.params()) :: Changeset.t()
def changeset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @insert_cast)
	|> Changeset.validate_required(@insert_reqr)
	|> Validate.name(:name)
	|> Validate.name(:user)
	|> Validate.name(:email)
	|> Validate.note(:note)
	|> Validate.key(:ecdh_public_key)
	|> Validate.key(:eddsa_public_key)
	|> Validate.key(:ethereum_address)
	|> Validate.key(:reflow_public_key)
	|> Validate.key(:bitcoin_public_key)
	|> Validate.email(:email)
	|> Validate.class(:classified_as)
	|> Changeset.unique_constraint(:user)
	|> Changeset.unique_constraint(:name)
	|> Changeset.unique_constraint(:email)
	|> Changeset.assoc_constraint(:primary_location)
end

# update changeset
@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema, params) do
	schema
	|> Changeset.cast(params, @update_cast)
	|> Validate.name(:name)
	|> Validate.name(:user)
	|> Validate.note(:note)
	|> Validate.email(:email)
	|> Validate.class(:classified_as)
	|> Changeset.unique_constraint(:user)
	|> Changeset.unique_constraint(:name)
	|> Changeset.assoc_constraint(:primary_location)
end
end
