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

defmodule Zenflows.VF.Intent.Domain do
@moduledoc "Domain logic of Intents."

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, ObjectControl}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.File
alias Zenflows.VF.{
	Action,
	Intent,
	Measure,
}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, Intent.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(Intent, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: Intent.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [Intent.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	{:ok, Page.all(Intent, page)}
end

@spec all!(Page.t()) :: [Intent.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec create(ExecutionContext.t(), Schema.params()) :: {:ok, Intent.t()} | {:error, term()}
def create(%ExecutionContext{} = ctx, params) do
	key = multi_key()
	cset = Intent.changeset(params)
	Multi.new()
	|> Multi.run("#{key}.authz", fn repo, _ ->
		if cset.valid? do
			facts = Facts.for_intent_create(repo, ctx, cset.changes)
			with :ok <- Authz.authorize(ctx, "intent.create", facts), do: {:ok, facts}
		else
			{:ok, nil}
		end
	end)
	|> Multi.insert(key, cset)
	|> File.Domain.multi_insert(key, :images, :intent_id)
	|> ObjectControl.Domain.multi_on_create(ctx, "intent", key)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec create!(ExecutionContext.t(), Schema.params()) :: Intent.t()
def create!(ctx, params) do
	{:ok, value} = create(ctx, params)
	value
end

@spec update(ExecutionContext.t(), Schema.id(), Schema.params())
	:: {:ok, Intent.t()} | {:error, term()}
def update(%ExecutionContext{} = ctx, id, params) do
	key = multi_key()
	Multi.new()
	|> Authz.multi_authorize("#{key}.authz", ctx, "intent.update",
		fn repo, _ -> Facts.for_intent_update(repo, ctx, id, params) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.update(key, &Intent.changeset(Map.fetch!(&1, "#{key}.one"), params))
	|> File.Domain.multi_update(key, :images, :intent_id)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec update!(ExecutionContext.t(), Schema.id(), Schema.params()) :: Intent.t()
def update!(ctx, id, params) do
	{:ok, value} = update(ctx, id, params)
	value
end

@spec delete(ExecutionContext.t(), Schema.id()) :: {:ok, Intent.t()} | {:error, term()}
def delete(%ExecutionContext{} = ctx, id) do
	key = multi_key()
	Multi.new()
	|> Authz.multi_authorize("#{key}.authz", ctx, "intent.delete",
		fn repo, _ -> Facts.for_object(repo, ctx, "intent", id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
	|> ObjectControl.Domain.multi_remove(ctx, "intent", id)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec delete!(ExecutionContext.t(), Schema.id()) :: Intent.t()
def delete!(ctx, id) do
	{:ok, value} = delete(ctx, id)
	value
end

@spec preload(Intent.t(), :action | :input_of | :output_of
		| :provider | :receiver
		| :resource_inventoried_as  | :resource_conforms_to
		| :resource_quantity | :effort_quantity | :available_quantity
		| :at_location | :published_in
		| :images)
	:: Intent.t()
def preload(int, x) when x in ~w[
	input_of output_of provider receiver resource_inventoried_as
	resource_conforms_to at_location published_in
]a,
	do: Repo.preload(int, x)
def preload(int, :action), do: Action.preload(int, :action)
def preload(int, x) when x in ~w[
	effort_quantity available_quantity resource_quantity
]a,
	do: Measure.preload(int, x)
def preload(int, :images),
	do: File.Domain.preload_gql(int, :images, :intent_id)

@spec multi_key() :: atom()
def multi_key(), do: :intent
end
