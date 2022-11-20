# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.VF.EconomicResource.Domain do
@moduledoc "Domain logic of EconomicResources."

alias Ecto.{Changeset, Multi}
alias Zenflows.DB.{Page, Repo, Schema}
alias Zenflows.VF.{
	Action,
	EconomicEvent,
	EconomicResource,
	EconomicResource.Query,
	Measure,
}

@spec one(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: {:ok, EconomicResource.t()} | {:error, String.t()}
def one(repo \\ Repo, _)
def one(repo, id) when is_binary(id), do: one(repo, id: id)
def one(repo, clauses) do
	case repo.get_by(EconomicResource, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec one!(Ecto.Repo.t(), Schema.id() | map() | Keyword.t())
	:: EconomicResource.t()
def one!(repo \\ Repo, id_or_clauses) do
	{:ok, value} = one(repo, id_or_clauses)
	value
end

@spec all(Page.t()) :: {:ok, [EconomicResource.t()]} | {:error, Changeset.t()}
def all(page \\ Page.new()) do
	with {:ok, q} <- Query.all(page) do
		{:ok, Page.all(q, page)}
	end
end

@spec all!(Page.t()) :: [EconomicResource.t()]
def all!(page \\ Page.new()) do
	{:ok, value} = all(page)
	value
end

@spec previous(EconomicResource.t() | Schema.id()) :: [EconomicEvent.t()]
def previous(_, _ \\ Page.new())
def previous(%EconomicResource{id: id}, page), do: previous(id, page)
def previous(id, page) do
	Query.previous(id)
	|> Page.all(page)
	|> Enum.sort(&(
		&1.previous_event_id == nil
		or &1.id == &2.previous_event_id
		or &1.id <= &2.id))
end

@spec classifications() :: [String.t()]
def classifications() do
	import Ecto.Query

	from(r in EconomicResource,
		select: fragment("distinct unnest(?)", r.classified_as))
	|> Repo.all()
end

@spec update(Schema.id(), Schema.params())
	:: {:ok, EconomicResource.t()} | {:error, String.t() | Changeset.t()}
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

@spec update!(Schema.id(), Schema.params()) :: EconomicResource.t()
def update!(id, params) do
	{:ok, value} = update(id, params)
	value
end

@spec delete(Schema.id()) ::
	{:ok, EconomicResource.t()} | {:error, String.t() | Changeset.t()}
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

@spec delete!(Schema.id) :: EconomicResource.t()
def delete!(id) do
	{:ok, value} = delete(id)
	value
end

@spec preload(EconomicResource.t(), :images
		| :conforms_to | :accounting_quantity
		| :onhand_quantity | :primary_accountable | :custodian
		| :stage | :state | :current_location | :lot | :contained_in
		| :unit_of_effort | :previous_event)
	:: EconomicResource.t()
def preload(eco_res, x) when x in ~w[
	images conforms_to primary_accountable custodian lot
	stage current_location contained_in unit_of_effort previous_event
]a,
	do: Repo.preload(eco_res, x)
def preload(eco_res, x) when x in ~w[accounting_quantity onhand_quantity]a,
	do: Measure.preload(eco_res, x)
def preload(eco_res, :state),
	do: Action.preload(eco_res, :state)

@spec multi_key() :: atom()
def multi_key(), do: :economic_resource

@spec multi_one(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_one(m, key \\ multi_key(), id) do
	Multi.run(m, key, fn repo, _ -> one(repo, id) end)
end

@spec multi_insert(Multi.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, key \\ multi_key(), params) do
	Multi.insert(m, key, EconomicResource.changeset(params))
end

@spec multi_update(Multi.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, key \\ multi_key(), id, params) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.update(key,
		&EconomicResource.changeset(Map.fetch!(&1, "#{key}.one"), params))
end

@spec multi_delete(Multi.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, key \\ multi_key(), id) do
	m
	|> multi_one("#{key}.one", id)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end
end
