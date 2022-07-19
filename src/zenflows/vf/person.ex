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

defmodule Zenflows.VF.Person do
@moduledoc "A natural person."

use Zenflows.DB.Schema

alias Zenflows.VF.{SpatialThing, Validate}

@type t() :: %__MODULE__{
	type: :per,
	name: String.t(),
	image: String.t() | nil,
	note: String.t() | nil,
	primary_location: SpatialThing.t() | nil,
	user: String.t(),
	email: String.t(),
	pubkeys: binary(),
	pubkeys_encoded: String.t() | nil,
}

schema "vf_agent" do
	field :type, Ecto.Enum, values: [:per], default: :per
	field :name, :string
	field :image, :string, virtual: true
	field :note, :string
	belongs_to :primary_location, SpatialThing
	field :user, :string
	field :email, :string
	field :pubkeys, :binary
	field :pubkeys_encoded, :string, virtual: true
end

@insert_reqr ~w[name user email]a
@insert_cast @insert_reqr ++ ~w[pubkeys_encoded image note primary_location_id]a
# TODO: Maybe add email to @update_cast as well?
@update_cast ~w[name image note primary_location_id user]a

# insert changeset
@doc false
@spec chgset(params()) :: Changeset.t()
def chgset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @insert_cast)
	|> Changeset.validate_required(@insert_reqr)
	|> Validate.name(:name)
	|> Validate.name(:user)
	|> Validate.name(:email)
	|> Validate.uri(:image)
	|> Validate.note(:note)
	|> check_email()
	|> decode_pubkeys()
	|> Changeset.unique_constraint(:user)
	|> Changeset.unique_constraint(:name)
	|> Changeset.unique_constraint(:email)
	|> Changeset.assoc_constraint(:primary_location)
end

# update changeset
@doc false
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema, params) do
	schema
	|> Changeset.cast(params, @update_cast)
	|> Validate.name(:name)
	|> Validate.name(:user)
	|> Validate.uri(:image)
	|> Validate.note(:note)
	|> check_email()
	|> Changeset.unique_constraint(:user)
	|> Changeset.unique_constraint(:name)
	|> Changeset.assoc_constraint(:primary_location)
end

# Validate that :email is a valid email address.
@spec check_email(Changeset.t()) :: Changeset.t()
defp check_email(cset) do
	# works good enough for now
	Changeset.validate_format(cset, :email, ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/)
end

@spec decode_pubkeys(Changeset.t()) :: Changeset.t()
defp decode_pubkeys(cset) do
	case Changeset.fetch_change(cset, :pubkeys_encoded) do
		{:ok, val} ->
			case Base.url_decode64(val) do
				{:ok, decoded} ->
					Changeset.put_change(cset, :pubkeys, decoded)

				:error ->
					Changeset.add_error(cset, :pubkeys, "not valid url-safe base64-encoded string")
			end
		:error ->
			cset
	end
end
end
