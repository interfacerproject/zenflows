defmodule Zenflows.SWPass.Resolv do
@moduledoc "Resolvers of softwarepassport-related queries."

alias Zenflows.SWPass.Domain

def import_repos(%{url: url}, _) do
	with {:ok, _} <- Domain.import_repos(url) do
		{:ok, "successfully imported"}
	else _ ->
		{:error, "something went wrong"}
	end
end

def project_agents(%{url: url}, _) do
	{:ok, Domain.project_agents(url)}
end
end
