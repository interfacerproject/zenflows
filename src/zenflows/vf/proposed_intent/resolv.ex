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

defmodule Zenflows.VF.ProposedIntent.Resolv do
@moduledoc false

alias Zenflows.VF.ProposedIntent.Domain

def propose_intent(params, _) do
	with {:ok, prop_int} <- Domain.create(params) do
		{:ok, %{proposed_intent: prop_int}}
	end
end

def delete_proposed_intent(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def published_in(prop_int, _, _) do
	prop_int = Domain.preload(prop_int, :published_in)
	{:ok, prop_int.published_in}
end

def publishes(prop_int, _, _) do
	prop_int = Domain.preload(prop_int, :publishes)
	{:ok, prop_int.publishes}
end
end
