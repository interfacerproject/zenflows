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

defmodule Zenflows.VF.Satisfaction.Domain do
@moduledoc "Domain logic of Satisfactions."

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{Measure, Satisfaction}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, Satisfaction.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(Satisfaction, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: Satisfaction.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [Satisfaction.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	{:ok, Page.all(Satisfaction, page)}
end

@spec all!(Page.t()) :: [Satisfaction.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec create(ExecutionContext.t(), Schema.params()) :: {:ok, Satisfaction.t()} | {:error, term()}
def create(%ExecutionContext{} = ctx, params) do
	key = multi_key()
	cset = Satisfaction.changeset(params)
	Multi.new()
	|> Multi.run("#{key}.authz", fn repo, _ ->
		if cset.valid? do
			facts = Facts.for_satisfaction_create(repo, ctx, cset.changes)
			with :ok <- Authz.authorize(ctx, "satisfaction.create", facts), do: {:ok, facts}
		else
			{:ok, nil}
		end
	end)
	|> Multi.insert(key, cset)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec create!(ExecutionContext.t(), Schema.params()) :: Satisfaction.t()
def create!(ctx, params) do
	{:ok, value} = create(ctx, params)
	value
end

@spec update(ExecutionContext.t(), Schema.id(), Schema.params())
	:: {:ok, Satisfaction.t()} | {:error, term()}
def update(%ExecutionContext{} = ctx, id, params) do
	key = multi_key()
	Multi.new()
	|> Authz.multi_authorize("#{key}.authz", ctx, "satisfaction.update",
		fn repo, _ -> Facts.for_satisfaction(repo, ctx, id, params) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.update(key, &Satisfaction.changeset(Map.fetch!(&1, "#{key}.one"), params))
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec update!(ExecutionContext.t(), Schema.id(), Schema.params()) :: Satisfaction.t()
def update!(ctx, id, params) do
	{:ok, value} = update(ctx, id, params)
	value
end

@spec delete(ExecutionContext.t(), Schema.id()) :: {:ok, Satisfaction.t()} | {:error, term()}
def delete(%ExecutionContext{} = ctx, id) do
	key = multi_key()
	Multi.new()
	|> Authz.multi_authorize("#{key}.authz", ctx, "satisfaction.delete",
		fn repo, _ -> Facts.for_satisfaction(repo, ctx, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec delete!(ExecutionContext.t(), Schema.id()) :: Satisfaction.t()
def delete!(ctx, id) do
	{:ok, value} = delete(ctx, id)
	value
end

@spec preload(Satisfaction.t(), :satisfies | :satisfied_by_event
		| :satisfied_by_commitment | :resource_quantity | :effort_quantity)
	:: Satisfaction.t()
def preload(satis, x) when x in ~w[
	satisfies satisfied_by_event satisfied_by_commitment
]a,
	do: Repo.preload(satis, x)
def preload(satis, x) when x in ~w[effort_quantity resource_quantity]a,
	do: Measure.preload(satis, x)

@spec multi_key() :: atom()
def multi_key(), do: :satisfaction
end
