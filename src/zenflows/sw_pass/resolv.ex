defmodule Zenflows.SWPass.Resolv do
@moduledoc "Resolvers of softwarepassport-related queries."

alias Zenflows.Admin
alias Zenflows.SWPass.Domain

def import_repos(%{url: url, admin_key: key}, _) do
	with :ok <- Admin.auth(key),
			{:ok, _} <- Domain.import_repos(url) do
		{:ok, "successfully imported"}
	else _ ->
		{:error, "something went wrong"}
	end
end

def project_agents(%{url: url}, _) do
	{:ok, Domain.project_agents(url)}
end
end
