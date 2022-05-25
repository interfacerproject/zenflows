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

object :spatial_thing_response do
	field :spatial_thing, non_null(:spatial_thing)
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

object :query_spatial_thing do
	field :spatial_thing, :spatial_thing do
		arg :id, non_null(:id)
		resolve &Resolv.spatial_thing/2
	end

	#spatialThings(start: ID, limit: Int): [SpatialThing!]
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
