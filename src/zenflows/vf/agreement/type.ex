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

defmodule Zenflows.VF.Agreement.Type do
@moduledoc "GraphQL types of Agreements."

use Absinthe.Schema.Notation

alias Zenflows.VF.Agreement.Resolv

@name """
An informal or formal textual identifier for an agreement.  Does not
imply uniqueness.
"""
@note "A textual description or comment."
@created "The date and time the agreement was created."

@desc ""
object :agreement do
	field :id, non_null(:id)

	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @created
	field :created, non_null(:datetime)
end

object :agreement_response do
	field :agreement, non_null(:agreement)
end

input_object :agreement_create_params do
	@desc @name
	field :name, non_null(:string)

	@desc @note
	field :note, :string

	@desc @created
	field :created, non_null(:datetime)
end

input_object :agreement_update_params do
	field :id, non_null(:id)

	@desc @name
	field :name, :string

	@desc @note
	field :note, :string

	@desc @created
	field :created, :datetime
end

object :query_agreement do
	field :agreement, :agreement do
		arg :id, non_null(:id)
		resolve &Resolv.agreement/2
	end
end

object :mutation_agreement do
	field :create_agreement, non_null(:agreement_response) do
		arg :agreement, non_null(:agreement_create_params)
		resolve &Resolv.create_agreement/2
	end

	field :update_agreement, non_null(:agreement_response) do
		arg :agreement, non_null(:agreement_update_params)
		resolve &Resolv.update_agreement/2
	end

	field :delete_agreement, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_agreement/2
	end
end
end
