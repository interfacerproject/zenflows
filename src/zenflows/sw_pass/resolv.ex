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

defmodule Zenflows.SWPass.Resolv do
@moduledoc "Resolvers of softwarepassport-related queries."

alias Zenflows.SWPass.Domain

def import_repos(%{url: url}, _) do
	case Domain.import_repos(url) do
		{:ok, _} -> {:ok, "successfully imported"}
		_ -> {:error, "something went wrong"}
	end
end

def project_agents(%{url: url}, _) do
	{:ok, Domain.project_agents(url)}
end
end
