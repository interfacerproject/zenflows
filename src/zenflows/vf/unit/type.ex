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

defmodule Zenflows.VF.Unit.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.Unit.Resolv

@label "A human readable label for the unit, can be language specific."
@symbol "A standard display symbol for a unit of measure."

@desc """
Defines a unit of measurement, along with its display symbol.  From OM2
vocabulary.
"""
object :unit do
	field :id, non_null(:id)

	@desc @label
	field :label, non_null(:string)

	@desc @symbol
	field :symbol, non_null(:string)
end

input_object :unit_create_params do
	@desc @label
	field :label, non_null(:string)

	@desc @symbol
	field :symbol, non_null(:string)
end

input_object :unit_update_params do
	field :id, non_null(:id)

	@desc @label
	field :label, :string

	@desc @symbol
	field :symbol, :string
end

object :unit_response do
	field :unit, non_null(:unit)
end

object :unit_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:unit)
end

object :unit_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:unit_edge)))
end

object :query_unit do
	field :unit, :unit do
		arg :id, non_null(:id)
		resolve &Resolv.unit/2
	end

	field :units, :unit_connection do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.units/2
	end
end

object :mutation_unit do
	field :create_unit, non_null(:unit_response) do
		arg :unit, non_null(:unit_create_params)
		resolve &Resolv.create_unit/2
	end

	field :update_unit, non_null(:unit_response) do
		arg :unit, non_null(:unit_update_params)
		resolve &Resolv.update_unit/2
	end

	field :delete_unit, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_unit/2
	end
end
end
