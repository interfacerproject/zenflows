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

defmodule Zenflows.VF.Person.Domain do
@moduledoc "Domain logic of Persons."

import Ecto.Query

alias Ecto.{Changeset, Multi}
alias Zenflows.Email
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.File
alias Zenflows.VF.{Person, Person.Query}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, Person.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(where(Person, type: :per), clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t()) :: Person.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [Person.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	with {:ok, q} <- Query.all(page) do
		{:ok, Page.all(q, page)}
	end
end

@spec all!(Page.t()) :: [Person.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec exists?(Keyword.t()) :: boolean()
def exists?(conds) do
	where(Person, ^conds) |> where(type: :per) |> Repo.exists?()
end

@spec pubkey(Schema.id()) :: {:ok, nil | String.t()} | {:error, String.t()}
def pubkey(id) do
	where(Person, type: :per, id: ^id)
	|> select([:eddsa_public_key]) |> Repo.one()
	|> case do
		nil -> {:error, "not found"}
		%{eddsa_public_key: pkey} -> {:ok, pkey}
	end
end

@spec request_email_verification(Person.t(), atom()) :: :ok | {:error, term()}
def request_email_verification(person, template) do
	url = case template do
		:interfacer_deployment -> "https://interfacer.dyne.org/email/reset-pass/"
		:interfacer_staging -> "https://interfacer-gui-staging.dyne.org/email/reset-pass/"
		:interfacer_testing -> "https://interfacer-gui-testing.dyne.org/email/reset-pass/"
		:interfacer_debugging -> "https://interfacer-gui-debugging.dyne.org/email/reset-pass/"
	end
	Email.Domain.request_email_verification(person, url)
end

@spec verify_email_verification(Person.t(), String.t()) :: :ok | {:error, String.t() | Changeset.t()}
def verify_email_verification(person, token) do
	with :ok <- Email.Domain.verify_email_verification(person, token),
			{:ok, _} <- __MODULE__.update(person.id, %{is_verified: true}) do
		:ok
	else
		:error -> {:error, "verification failed"}
		{:error, reason} -> {:error, reason}
	end
end

@spec create(Schema.params()) :: {:ok, Person.t()} | {:error, Changeset.t()}
def create(params) do
	key = multi_key()
	Multi.new()
	|> multi_insert(params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec create!(Schema.params()) :: Person.t()
def create!(params) do
	{:ok, value} = create(params)
	value
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, Person.t()} | {:error, String.t() | Changeset.t()}
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

@spec update!(Schema.id(), Schema.params()) :: Person.t()
def update!(id, params) do
	{:ok, value} = __MODULE__.update(id, params)
	value
end

@spec delete(Schema.id()) ::
	{:ok, Person.t()} | {:error, String.t() | Changeset.t()}
def delete(id) do
	key = multi_key()
	Multi.new()
	|> multi_delete(id)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec claim(Schema.id()) ::
	{:ok, Person.t()} | {:error, String.t() | Changeset.t()}
def claim(id) do
	Multi.new()
	|> multi_one(id)
	|> Multi.run(:claim_id, &Zenflows.DID.claim/2)
	|> Repo.transaction()
	|> case do
		{:ok, %{claim_id: value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec delete!(Schema.id()) :: Person.t()
def delete!(id) do
	{:ok, value} = delete(id)
	value
end

@spec preload(Person.t(), :images | :primary_location) :: Person.t()
def preload(per, x) when x in ~w[primary_location]a,
	do: Repo.preload(per, x)
def preload(per, :images),
	do: File.Domain.preload_gql(per, :images, :agent_id)

@spec multi_key() :: atom()
def multi_key(), do: :person

@spec multi_one(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_one(m, key \\ multi_key(), id) do
	Multi.run(m, key, fn repo, _ -> one(repo, id) end)
end

@spec multi_insert(Multi.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, key \\ multi_key(), params) do
	m
	|> Multi.insert(key, Person.changeset(params))
	|> File.Domain.multi_insert(key, :images, :agent_id)
end

@spec multi_update(Multi.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, key \\ multi_key(), id, params) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.update(key,
		&Person.changeset(Map.fetch!(&1, "#{key}.one"), params))
	|> File.Domain.multi_update(key, :images, :agent_id)
end

@spec multi_delete(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, key \\ multi_key(), id) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end
end
