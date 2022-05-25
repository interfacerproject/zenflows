defmodule Zenflows.VF.Duration.Type do
@moduledoc "GraphQL types of Durations."

use Absinthe.Schema.Notation

@numeric_duration """
A number representing the duration, will be paired with a unit.
"""
@unit_type "A unit of measure."

@desc "A `Duration` represents an interval between two `DateTime` values."
object :duration do
	@desc @numeric_duration
	field :numeric_duration, non_null(:float)

	@desc @unit_type
	field :unit_type, non_null(:time_unit)
end

@desc "Mutation input structure for defining time durations."
input_object :iduration, name: "IDuration" do
	@desc @numeric_duration
	field :numeric_duration, non_null(:float)

	@desc @unit_type
	field :unit_type, non_null(:time_unit)
end
end
