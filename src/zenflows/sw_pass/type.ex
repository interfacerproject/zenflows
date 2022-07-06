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
		@desc "The configuration-defined key to authenticate admin calls."
		arg :admin_key, non_null(:string)

		@desc "The URL where all the repository information is listed."
		arg :url, non_null(:string)

		resolve &Resolv.import_repos/2
	end
end
end
