# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.VF.Person.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.Person.Resolv

@name "The name that this agent will be referred to by."
@images """
The image files relevant to the agent, such as a logo, avatar, photo, etc.
"""
@note "A textual description or comment."
@primary_location """
The main place an agent is located, often an address where activities
occur and mail can be sent.	 This is usually a mappable geographic
location.  It also could be a website address, as in the case of agents
who have no physical location.
"""
@primary_location_id "(`SpatialThing`) #{@primary_location}"
@user "Username of the agent.  Implies uniqueness."
@email "Email address of the agent.  Implies uniqueness."
@ecdh_public_key "ecdh public key, encoded by zenroom"
@eddsa_public_key "eddsa public key, encoded by zenroom"
@ethereum_address "ethereum address, encoded by zenroom"
@reflow_public_key "reflow public key, encoded by zenroom"
@schnorr_public_key "schnorr public key, encoded by zenroom"

@desc "A natural person."
object :person do
	interface :agent

	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @images
	field :images, list_of(non_null(:file)), resolve: &Resolv.images/3

	@desc @note
	field :note, :string

	@desc @primary_location
	field :primary_location, :spatial_thing,
		resolve: &Resolv.primary_location/3

	@desc @user
	field :user, non_null(:string)

	@desc @email
	field :email, non_null(:string)

	@desc @ecdh_public_key
	field :ecdh_public_key, :string

	@desc @eddsa_public_key
	field :eddsa_public_key, :string

	@desc @ethereum_address
	field :ethereum_address, :string

	@desc @reflow_public_key
	field :reflow_public_key, :string

	@desc @schnorr_public_key
	field :schnorr_public_key, :string
end

@desc "Person eddsa public key"
object :person_pubkey do
	@desc @eddsa_public_key
	field :eddsa_public_key, :string
end

input_object :person_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @images
	field :images, list_of(non_null(:ifile))

	@desc @note
	field :note, :string

	@desc @primary_location_id
	field :primary_location_id, :id, name: "primary_location"

	@desc @user
	field :user, non_null(:string)

	@desc @email
	field :email, non_null(:string)

	@desc @ecdh_public_key
	field :ecdh_public_key, :string

	@desc @eddsa_public_key
	field :eddsa_public_key, :string

	@desc @ethereum_address
	field :ethereum_address, :string

	@desc @reflow_public_key
	field :reflow_public_key, :string

	@desc @schnorr_public_key
	field :schnorr_public_key, :string
end

input_object :person_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @primary_location_id
	field :primary_location_id, :id, name: "primary_location"

	@desc @user
	field :user, :string
end

object :person_response do
	field :agent, non_null(:person)
end

object :person_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:person)
end

object :person_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:person_edge)))
end

input_object :person_filter_params do
	field :name, :string
	field :user, :string
	field :user_or_name, :string
end

object :query_person do
	@desc "Find a person by their ID."
	field :person, :person do
		arg :id, non_null(:id)
		resolve &Resolv.person/2
	end

	@desc """
	Loads all people who have publicly registered with this collaboration
	space.
	"""
	field :people, :person_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		arg :filter, :person_filter_params
		resolve &Resolv.people/2
	end

	@desc "Check if a person exists by email xor username."
	field :person_exists, non_null(:boolean) do
		meta only_guest?: true
		arg :email, :string
		arg :user, :string
		resolve &Resolv.person_exists/2
	end

	@desc "If exists, find a person by email and eddsa-public-key."
	field :person_check, non_null(:person) do
		meta only_guest?: true
		arg :email, non_null(:string)
		arg :eddsa_public_key, non_null(:string)
		resolve &Resolv.person_check/2
	end

	@desc "Retrieve a Person's public key by its id."
	field :person_pubkey, non_null(:string) do
		meta only_guest?: true
		arg :id, non_null(:id)
		resolve &Resolv.person_pubkey/2
	end
end

object :mutation_person do
	@desc "Registers a new (human) person with the collaboration space."
	field :create_person, non_null(:person_response) do
		meta only_admin?: true
		arg :person, non_null(:person_create_params)
		resolve &Resolv.create_person/2
	end

	@desc "Update profile details."
	field :update_person, non_null(:person_response) do
		arg :person, non_null(:person_update_params)
		resolve &Resolv.update_person/2
	end

	@desc """
	Erase record of a person and thus remove them from the
	collaboration space.
	"""
	field :delete_person, non_null(:boolean) do
		meta only_admin?: true
		arg :id, non_null(:id)
		resolve &Resolv.delete_person/2
	end
end
end
