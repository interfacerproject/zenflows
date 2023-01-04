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

defmodule Zenflows.VF.ProcessSpecification.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.ProcessSpecification.Resolv

@name """
An informal or formal textual identifier for the process.  Does not
imply uniqueness.
"""
@note "A textual description or comment."

@desc "Specifies the kind of process."
object :process_specification do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

input_object :process_specification_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string
end

input_object :process_specification_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string
end

object :process_specification_response do
	field :process_specification, non_null(:process_specification)
end

object :process_specification_edge do
	field :cursor, non_null(:id)
	field :node, non_null(:process_specification)
end

object :process_specification_connection do
	field :page_info, non_null(:page_info)
	field :edges, non_null(list_of(non_null(:process_specification_edge)))
end

object :query_process_specification do
	field :process_specification, :process_specification do
		arg :id, non_null(:id)
		resolve &Resolv.process_specification/2
	end

	field :process_specifications, non_null(:process_specification_connection) do
		arg :first, :integer
		arg :after, :id
		arg :last, :integer
		arg :before, :id
		resolve &Resolv.process_specifications/2
	end
end

object :mutation_process_specification do
	field :create_process_specification, non_null(:process_specification_response) do
		arg :process_specification, non_null(:process_specification_create_params)
		resolve &Resolv.create_process_specification/2
	end

	field :update_process_specification, non_null(:process_specification_response) do
		arg :process_specification, non_null(:process_specification_update_params)
		resolve &Resolv.update_process_specification/2
	end

	field :delete_process_specification, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_process_specification/2
	end
end
end
