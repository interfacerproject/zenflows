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

defmodule Zenflows.VF.Intent.Domain do
@moduledoc "Domain logic of Intents."

alias Ecto.Multi
alias Zenflows.DB.Repo
alias Zenflows.VF.{
	Action,
	Intent,
	Measure,
}

@typep repo() :: Ecto.Repo.t()
@typep chgset() :: Ecto.Changeset.t()
@typep id() :: Zenflows.DB.Schema.id()
@typep params() :: Zenflows.DB.Schema.params()

@spec one(repo(), id()) :: {:ok, Intent.t()} | {:error, String.t()}
def one(repo \\ Repo, id) do
	one_by(repo, id: id)
end

@spec one_by(repo(), map() | Keyword.t())
	:: {:ok, Intent.t()} | {:error, String.t()}
def one_by(repo \\ Repo, clauses) do
	case repo.get_by(Intent, clauses) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@spec create(params()) :: {:ok, Intent.t()} | {:error, chgset()}
def create(params) do
	Multi.new()
	|> Multi.insert(:insert, Intent.chgset(params))
	|> Repo.transaction()
	|> case do
		{:ok, %{insert: i}} -> {:ok, i}
		{:error, _, cset, _} -> {:error, cset}
	end
end

@spec update(id(), params()) ::
	{:ok, Intent.t()} | {:error, String.t() | chgset()}
def update(id, params) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one_by/2)
	|> Multi.update(:update, &Intent.chgset(&1.one, params))
	|> Repo.transaction()
	|> case do
		{:ok, %{update: i}} -> {:ok, i}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec delete(id()) :: {:ok, Intent.t()} | {:error, String.t() | chgset()}
def delete(id) do
	Multi.new()
	|> Multi.put(:id, id)
	|> Multi.run(:one, &one_by/2)
	|> Multi.delete(:delete, &(&1.one))
	|> Repo.transaction()
	|> case do
		{:ok, %{delete: i}} -> {:ok, i}
		{:error, _, msg_or_cset, _} -> {:error, msg_or_cset}
	end
end

@spec preload(Intent.t(), :action | :input_of | :output_of
		| :provider | :receiver
		| :resource_inventoried_as  | :resource_conforms_to
		| :resource_quantity | :effort_quantity | :available_quantity
		| :at_location | :published_in)
	:: Intent.t()
def preload(int, :action) do
	Action.preload(int, :action)
end

def preload(int, :input_of) do
	Repo.preload(int, :input_of)
end

def preload(int, :output_of) do
	Repo.preload(int, :output_of)
end

def preload(int, :provider) do
	Repo.preload(int, :provider)
end

def preload(int, :receiver) do
	Repo.preload(int, :receiver)
end

def preload(int, :resource_inventoried_as) do
	Repo.preload(int, :resource_inventoried_as)
end

def preload(int, :resource_conforms_to) do
	Repo.preload(int, :resource_conforms_to)
end

def preload(int, :resource_quantity) do
	Measure.preload(int, :resource_quantity)
end

def preload(int, :effort_quantity) do
	Measure.preload(int, :effort_quantity)
end

def preload(int, :available_quantity) do
	Measure.preload(int, :available_quantity)
end

def preload(int, :at_location) do
	Repo.preload(int, :at_location)
end

def preload(int, :published_in) do
	Repo.preload(int, :published_in)
end
end
