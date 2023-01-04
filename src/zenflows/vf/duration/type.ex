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

defmodule Zenflows.VF.Duration.Type do
@moduledoc false

use Absinthe.Schema.Notation

@numeric_duration """
A number representing the duration, will be paired with a unit.
"""
@unit_type "A unit of measure."

@desc "A `Duration` represents an interval between two `DateTime` values."
object :duration do
	@desc @numeric_duration
	field :numeric_duration, non_null(:decimal)

	@desc @unit_type
	field :unit_type, non_null(:time_unit)
end

@desc "Mutation input structure for defining time durations."
input_object :iduration, name: "IDuration" do
	@desc @numeric_duration
	field :numeric_duration, non_null(:decimal)

	@desc @unit_type
	field :unit_type, non_null(:time_unit)
end
end
