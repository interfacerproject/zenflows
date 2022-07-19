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

defmodule Zenflows.VF.Measure.Type do
@moduledoc "GraphQL types of Measures."

use Absinthe.Schema.Notation

alias Zenflows.VF.Measure.Resolv

@has_numerical_value """
A number representing the quantity, will be paired with a unit.
"""
@has_unit "A unit of measure."

@desc """
Semantic meaning for measurements: binds a quantity to its measurement
unit.  See http://www.qudt.org/pages/QUDToverviewPage.html .
"""
object :measure do
	@desc @has_numerical_value
	field :has_numerical_value, non_null(:float)

	@desc @has_unit
	field :has_unit, :unit, resolve: &Resolv.has_unit/3
end

@desc """
Mutation input structure for defining measurements.  Should be nulled
if not present, rather than empty.
"""
input_object :imeasure, name: "IMeasure" do
	@desc @has_numerical_value
	field :has_numerical_value, non_null(:float)

	@desc "(`Unit`) " <> @has_unit
	field :has_unit_id, :id, name: "has_unit"
end
end
