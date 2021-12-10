defmodule Zenflows.Valflow.RoleBehavior.Resolv do
@moduledoc "Resolvers of RoleBehaviors."

alias Zenflows.Valflow.RoleBehavior.Domain

def role_behavior(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_role_behavior(%{role_behavior: params}, _info) do
	with {:ok, role_beh} <- Domain.create(params) do
		{:ok, %{role_behavior: role_beh}}
	end
end

def update_role_behavior(%{role_behavior: %{id: id} = params}, _info) do
	with {:ok, role_beh} <- Domain.update(id, params) do
		{:ok, %{role_behavior: role_beh}}
	end
end

def delete_role_behavior(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
