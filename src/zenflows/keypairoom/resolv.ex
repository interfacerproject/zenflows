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

defmodule Zenflows.Keypairoom.Resolv do
@moduledoc "Resolvers of keypairoom-related queries."

require Logger

alias Zenflows.Keypairoom.Domain

def keypairoom_server(%{first_registration: first?, email: email}, _) do
	case Domain.keypairoom_server(first?, email) do
		{:ok, value} ->
			{:ok, value}

		{:error, reason} ->
			{:error, reason}
	end
end
end
