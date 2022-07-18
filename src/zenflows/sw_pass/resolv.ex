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
