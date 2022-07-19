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

defmodule Zenflows.VF.Action.Type do
@moduledoc "GraphQL types of Actions."

use Absinthe.Schema.Notation

@desc """
An action verb defining the kind of event, commitment, or intent.
It is recommended that the lowercase action verb should be used as the
record ID in order that references to `Action`s elsewhere in the system
are easily readable.
"""
object :action do
	field :id, non_null(:string)

	@desc "A unique verb which defines the action."
	field :label, non_null(:string)

	@desc """
	The accounting effect of an economic event on a resource,
	increment, decrement, no effect, or decrement resource and
	increment "to" resource.
	"""
	field :resource_effect, non_null(:string) # "increment", "decrement", "noEffect", "decrementIncrement"

	@desc """
	The onhand effect of an economic event on a resource, increment,
	decrement, no effect, or decrement resource and increment "to"
	resource.
	"""
	field :onhand_effect, non_null(:string) # "increment", "decrement", "noEffect", "decrementIncrement"

	@desc "Denotes if a process input or output, or not related to a process."
	field :input_output, :string # "input", "output", "notApplicable"

	@desc """
	The action that should be included on the other direction of
	the process, for example accept with modify.
	"""
	field :pairs_with, :string # "notApplicable", (any of the action labels)
end
end
