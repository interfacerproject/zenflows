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

defmodule Zenflows.VF.ProposedIntent.Domain do
@moduledoc "Domain logic of ProposedIntents."

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.ProposedIntent

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, ProposedIntent.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(ProposedIntent, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: ProposedIntent.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [ProposedIntent.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	{:ok, Page.all(ProposedIntent, page)}
end

@spec all!(Page.t()) :: [ProposedIntent.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec create(ExecutionContext.t(), Schema.params()) :: {:ok, ProposedIntent.t()} | {:error, term()}
def create(%ExecutionContext{} = ctx, params) do
	key = multi_key()
	cset = ProposedIntent.changeset(params)
	Multi.new()
	|> Multi.run("#{key}.authz", fn repo, _ ->
		if cset.valid? do
			facts = Facts.for_proposed_intent_create(repo, ctx,
				cset.changes.published_in_id, cset.changes.publishes_id)
			with :ok <- Authz.authorize(ctx, "proposed_intent.create", facts), do: {:ok, facts}
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

@spec create!(ExecutionContext.t(), Schema.params()) :: ProposedIntent.t()
def create!(ctx, params) do
	{:ok, value} = create(ctx, params)
	value
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, ProposedIntent.t()} | {:error, String.t() | Changeset.t()}
def update(id, params) do
	key = multi_key()
	Multi.new()
	|> multi_update(id, params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec update!(Schema.id(), Schema.params()) :: ProposedIntent.t()
def update!(id, params) do
	{:ok, value} = update(id, params)
	value
end

@spec delete(ExecutionContext.t(), Schema.id()) :: {:ok, ProposedIntent.t()} | {:error, term()}
def delete(%ExecutionContext{} = ctx, id) do
	key = multi_key()
	Multi.new()
	|> Authz.multi_authorize("#{key}.authz", ctx, "proposed_intent.delete",
		fn repo, _ -> Facts.for_proposed_intent(repo, ctx, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec delete!(ExecutionContext.t(), Schema.id()) :: ProposedIntent.t()
def delete!(ctx, id) do
	{:ok, value} = delete(ctx, id)
	value
end

@spec preload(ProposedIntent.t(), :published_in | :publishes)
	:: ProposedIntent.t()
def preload(prop_int, x) when x in ~w[published_in publishes]a do
	Repo.preload(prop_int, x)
end

@spec multi_key() :: atom()
def multi_key(), do: :proposed_intent

@spec multi_one(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_one(m, key \\ multi_key(), id) do
	Multi.run(m, key, fn repo, _ -> one(repo, id) end)
end

@spec multi_update(Multi.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, key \\ multi_key(), id, params) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.update(key,
		&ProposedIntent.changeset(Map.fetch!(&1, "#{key}.one"), params))
end
end
