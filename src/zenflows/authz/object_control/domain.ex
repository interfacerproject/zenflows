# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.Authz.ObjectControl.Domain do
@moduledoc "Reads and writes of object control (processes, proposals, intents)."

require Ecto.Query

alias Ecto.Multi
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, Log, ObjectControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.Person

@spec one(Ecto.Repo.t(), String.t(), String.t()) :: {:ok, ObjectControl.t()} | {:error, String.t()}
def one(repo \\ Repo, type, id) do
	case repo.get_by(ObjectControl, target_type: type, target_id: id) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@doc """
Record the acting Person as controller of the object stored under `key`.
Services and anonymous calls create objects without a control row.
"""
@spec multi_on_create(Multi.t(), ExecutionContext.t(), String.t(), term()) :: Multi.t()
def multi_on_create(m, %ExecutionContext{principal: %Person{id: pid}} = ctx, type, key) do
	m
	|> Multi.run("#{key}.control", fn repo, changes ->
		%{target_type: type, target_id: Map.fetch!(changes, key).id,
			controller_id: pid, source: :creation}
		|> ObjectControl.changeset()
		|> repo.insert()
	end)
	|> Log.multi_insert("#{key}.control.log", ctx, fn changes ->
		c = Map.fetch!(changes, "#{key}.control")
		%{action: "object_control.set", target_type: type, target_id: c.target_id,
			subject_id: c.controller_id,
			after: %{controller_id: c.controller_id, source: c.source, target_type: type}}
	end)
end
def multi_on_create(m, _ctx, _type, _key), do: m

@doc "Remove the control row of a deleted object (if any) and log it."
@spec multi_remove(Multi.t(), ExecutionContext.t(), String.t(), String.t()) :: Multi.t()
def multi_remove(m, ctx, type, id) do
	key = "object_control.remove.#{type}.#{id}"
	m
	|> Multi.run(key, fn repo, _ ->
		case one(repo, type, id) do
			{:ok, c} -> with {:ok, _} <- repo.delete(c), do: {:ok, c}
			{:error, _} -> {:ok, nil}
		end
	end)
	|> Log.multi_insert("#{key}.log", ctx, fn changes ->
		case Map.fetch!(changes, key) do
			nil -> nil
			c -> %{action: "object_control.remove", target_type: type, target_id: id,
				subject_id: c.controller_id,
				before: %{controller_id: c.controller_id, source: c.source,
					epoch: c.epoch, target_type: type}}
		end
	end)
end

@doc """
Admin key only: create or replace the controller, with a logged reason.
`type` is validated against `ObjectControl.types/0`; the target object
itself is not checked for existence (`target_id` is polymorphic across
three tables and carries no foreign key).
"""
@spec assign(ExecutionContext.t(), String.t(), String.t(), String.t(), String.t())
	:: {:ok, ObjectControl.t()} | {:error, term()}
def assign(ctx, type, id, person_id, reason) do
	Multi.new()
	|> Multi.run(:authz, fn _, _ ->
		with :ok <- Authz.authorize(ctx, "object_control.assign", %Facts{}), do: {:ok, nil}
	end)
	|> Multi.run(:checks, fn repo, _ ->
		cond do
			type not in ObjectControl.types() -> {:error, "unknown target type"}
			not (is_binary(reason) and String.trim(reason) != "") -> {:error, "reason is required"}
			not repo.exists?(Ecto.Query.from(p in Person, where: p.id == ^person_id and p.type == :per)) ->
				{:error, "person not found"}
			true -> {:ok, nil}
		end
	end)
	|> Multi.run(:control, fn repo, _ ->
		case repo.one(Ecto.Query.from(c in ObjectControl,
				where: c.target_type == ^type and c.target_id == ^id, lock: "FOR UPDATE")) do
			nil ->
				%{target_type: type, target_id: id, controller_id: person_id, source: :admin}
				|> ObjectControl.changeset()
				|> repo.insert()
			c ->
				c
				|> ObjectControl.changeset(%{controller_id: person_id, source: :admin, epoch: c.epoch + 1})
				|> repo.update()
		end
	end)
	|> Log.multi_insert(:log, ctx, fn %{control: c} ->
		%{action: "object_control.set", target_type: type, target_id: id,
			subject_id: c.controller_id, reason: reason,
			after: %{controller_id: c.controller_id, source: c.source, target_type: type}}
	end)
	|> Repo.transaction()
	|> case do
		{:ok, %{control: c}} -> {:ok, c}
		{:error, _, reason, _} -> {:error, reason}
	end
end
end
