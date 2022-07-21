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

defmodule Zenflows.VF.Person.Type do
@moduledoc "GraphQL types of Persons."

use Absinthe.Schema.Notation

alias Zenflows.VF.Person.Resolv

@name "The name that this agent will be referred to by."
@image """
The URI to an image relevant to the agent, such as a logo, avatar,
photo, etc.
"""
@note "A textual description or comment."
@primary_location """
The main place an agent is located, often an address where activities
occur and mail can be sent.	 This is usually a mappable geographic
location.  It also could be a website address, as in the case of agents
who have no physical location.
"""
@user "Username of the agent.  Implies uniqueness."
@email "Email address of the agent.  Implies uniqueness."
@dilithium_public_key "dilithium public key, encoded by zenroom"
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

	@desc @image
	field :image, :uri

	@desc @note
	field :note, :string

	@desc @primary_location
	field :primary_location, :spatial_thing,
		resolve: &Resolv.primary_location/3

	@desc @user
	field :user, non_null(:string)

	@desc @email
	field :email, non_null(:string)

	@desc @dilithium_public_key
	field :dilithium_public_key, :string

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

object :person_response do
	field :agent, non_null(:person)
end

input_object :person_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @image
	field :image, :uri

	@desc @note
	field :note, :string

	# TODO: When
	# https://github.com/absinthe-graphql/absinthe/issues/1126 results,
	# apply the correct changes if any.
	@desc "(`SpatialThing`) " <> @primary_location
	field :primary_location_id, :id, name: "primary_location"

	@desc @user
	field :user, non_null(:string)

	@desc @email
	field :email, non_null(:string)

	@desc @dilithium_public_key
	field :dilithium_public_key, :string

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

	@desc @image
	field :image, :uri

	@desc @note
	field :note, :string

	@desc "(`SpatialThing`) " <> @primary_location
	field :primary_location_id, :id, name: "primary_location"

	@desc @user
	field :user, :string
end

object :query_person do
	@desc "Find a person by their ID."
	field :person, :person do
		arg :id, non_null(:id)
		resolve &Resolv.person/2
	end

	#"Loads all people who have publicly registered with this collaboration space."
	#people(start: ID, limit: Int): [Person!]
end

object :mutation_person do
	@desc "Registers a new (human) person with the collaboration space."
	field :create_person, non_null(:person_response) do
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
		arg :id, non_null(:id)
		resolve &Resolv.delete_person/2
	end
end
end
