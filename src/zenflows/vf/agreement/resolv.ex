defmodule Zenflows.VF.Agreement.Resolv do
@moduledoc "Resolvers of Agreements."

alias Zenflows.VF.Agreement.Domain

def agreement(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_agreement(%{agreement: params}, _info) do
	with {:ok, agreem} <- Domain.create(params) do
		{:ok, %{agreement: agreem}}
	end
end

def update_agreement(%{agreement: %{id: id} = params}, _info) do
	with {:ok, agreem} <- Domain.update(id, params) do
		{:ok, %{agreement: agreem}}
	end
end

def delete_agreement(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end
end
