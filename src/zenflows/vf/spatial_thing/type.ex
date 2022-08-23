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

defmodule Zenflows.VF.SpatialThing.Type do
@moduledoc "GraphQL types of SpatialThings."
# Basically, a fancy name for (geo)location.  :P

use Absinthe.Schema.Notation

alias Zenflows.VF.SpatialThing.Resolv

@name """
An informal or formal textual identifier for a location.  Does not
imply uniqueness.
"""
@mappable_address """
An address that will be recognized as mappable by mapping software.
"""
@lat "Latitude."
@long "Longitude."
@alt "Altitude."
@note "A textual description or comment."

@desc "A physical mappable location."
object :spatial_thing do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @mappable_address
	field :mappable_address, :string

	@desc @lat
	field :lat, :float

	@desc @long
	field :long, :float

	@desc @alt
	field :alt, :float

	@desc @note
	field :note, :string
end

input_object :spatial_thing_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @mappable_address
	field :mappable_address, :string

	@desc @lat
	field :lat, :float

	@desc @long
	field :long, :float

	@desc @alt
	field :alt, :float

	@desc @note
	field :note, :string
end

input_object :spatial_thing_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @mappable_address
	field :mappable_address, :string

	@desc @lat
	field :lat, :float

	@desc @long
	field :long, :float

	@desc @alt
	field :alt, :float

	@desc @note
	field :note, :string
end

object :spatial_thing_response do
	field :spatial_thing, non_null(:spatial_thing)
end

object :spatial_thing_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:spatial_thing)
end

object :spatial_thing_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:spatial_thing_edge)))
end

object :query_spatial_thing do
	field :spatial_thing, :spatial_thing do
		arg :id, non_null(:id)
		resolve &Resolv.spatial_thing/2
	end

	field :spatial_things, :spatial_thing_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.spatial_things/2
	end
end

object :mutation_spatial_thing do
	field :create_spatial_thing, non_null(:spatial_thing_response) do
		arg :spatial_thing, non_null(:spatial_thing_create_params)
		resolve &Resolv.create_spatial_thing/2
	end

	field :update_spatial_thing, non_null(:spatial_thing_response) do
		arg :spatial_thing, non_null(:spatial_thing_update_params)
		resolve &Resolv.update_spatial_thing/2
	end

	field :delete_spatial_thing, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_spatial_thing/2
	end
end
end
