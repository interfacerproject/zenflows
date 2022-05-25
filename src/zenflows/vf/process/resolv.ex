defmodule Zenflows.VF.Process.Resolv do
@moduledoc "Resolvers of Process."

use Absinthe.Schema.Notation

alias Zenflows.VF.{Process, Process.Domain}

def process(%{id: id}, _info) do
	{:ok, Domain.by_id(id)}
end

def create_process(%{process: params}, _info) do
	with {:ok, process} <- Domain.create(params) do
		{:ok, %{process: process}}
	end
end

def update_process(%{process: %{id: id} = params}, _info) do
	with {:ok, proc} <- Domain.update(id, params) do
		{:ok, %{process: proc}}
	end
end

def delete_process(%{id: id}, _info) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def based_on(%Process{} = proc, _args, _info) do
	proc = Domain.preload(proc, :based_on)
	{:ok, proc.based_on}
end

def planned_within(%Process{} = proc, _args, _info) do
	proc = Domain.preload(proc, :planned_within)
	{:ok, proc.planned_within}
end

def nested_in(%Process{} = proc, _args, _info) do
	proc = Domain.preload(proc, :nested_in)
	{:ok, proc.nested_in}
end
end
