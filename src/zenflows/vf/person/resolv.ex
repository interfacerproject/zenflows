# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.VF.Person.Resolv do
@moduledoc false

alias Ecto.Changeset
alias Zenflows.DB.Validate
alias Zenflows.GQL.Connection
alias Zenflows.VF.Person.Domain

def person(params, _) do
	Domain.one(params)
end

def people(params, _) do
	with {:ok, page} <- Connection.parse(params),
			{:ok, schemas} <- Domain.all(page) do
		{:ok, Connection.from_list(schemas, page)}
	end
end

def person_exists(params, _) do
	with {:ok, parsed} <- parse_person_exists(params) do
		{:ok, parsed |> Map.to_list() |> Domain.exists?()}
	end
end

def person_check(params, _) do
	Domain.one(params)
end

def person_pubkey(%{id: id}, _) do
	Domain.pubkey(id)
end

def create_person(%{person: params}, _) do
	with {:ok, per} <- Domain.create(params) do
		{:ok, %{agent: per}}
	end
end

def update_person(%{person: %{id: id} = params}, _) do
	with {:ok, per} <- Domain.update(id, params) do
		{:ok, %{agent: per}}
	end
end

def delete_person(%{id: id}, _) do
	with {:ok, _} <- Domain.delete(id) do
		{:ok, true}
	end
end

def claim_person(%{id: id}, _) do
	with {:ok, did} <- Domain.claim(id) do
		{:ok, did}
	end
end

def images(per, _, _) do
	per = Domain.preload(per, :images)
	{:ok, per.images}
end

def primary_location(per, _, _) do
	per = Domain.preload(per, :primary_location)
	{:ok, per.primary_location}
end

@spec parse_person_exists(map()) :: {:ok, map()} | {:error, Changeset.t()}
def parse_person_exists(params) do
	{%{}, %{email: :string, user: :string}}
	|> Changeset.cast(params, [:email, :user])
	|> Validate.exist_xor([:email, :user])
	|> Validate.email(:email)
	|> Validate.name(:user)
	|> Changeset.apply_action(nil)
end
end
