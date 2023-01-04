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

defmodule Zenflows.SWPass.Type do
@moduledoc "GraphQL types of SWPass."

use Absinthe.Schema.Notation

alias Zenflows.SWPass.Resolv

object :query_sw_pass do
	@desc "List all the agents associated in a project."
	field :project_agents, list_of(:agent) do
		@desc "The URL to the project."
		arg :url, non_null(:string)

		resolve &Resolv.project_agents/2
	end
end

object :mutation_sw_pass do
	@desc "Import repositories from a softwarepassport instance."
	field :import_repos, :string do
		meta only_admin?: true

		@desc "The URL where all the repository information is listed."
		arg :url, non_null(:string)
		resolve &Resolv.import_repos/2
	end
end
end
