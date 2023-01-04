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

defmodule Zenflows.Keypairoom.Type do
@moduledoc "GraphQL types of Keypairoom."

use Absinthe.Schema.Notation

alias Zenflows.Keypairoom.Resolv

object :mutation_keypairoom do
	field :keypairoom_server, non_null(:string) do
		meta only_guest?: true

		arg :first_registration, non_null(:boolean)
		arg :user_data, non_null(:string)
		resolve &Resolv.keypairoom_server/2
	end
end
end
