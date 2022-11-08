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

defmodule Zenflows.VF.Proposal.Filter do
@moduledoc false

import Ecto.Query

alias Ecto.{Changeset, Queryable}
alias Zenflows.DB.{ID, Page, Schema, Validate}
alias Zenflows.VF.Proposal

@spec all(Page.t()) :: {:ok, Queryable.t()} | {:error, Changeset.t()}
def all(%{filter: nil}), do: {:ok, Proposal}
def all(%{filter: params}) do
	with {:ok, filters} <- all_validate(params) do
		{:ok, Enum.reduce(filters, Proposal, &all_f(&2, &1))}
	end
end

@spec all_f(Queryable.t(), {atom(), term()}) :: Queryable.t()
defp all_f(q, {:primary_intents_resource_inventoried_as_conforms_to, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], r.conforms_to_id in ^v)
end
defp all_f(q, {:or_primary_intents_resource_inventoried_as_conforms_to, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], r.conforms_to_id in ^v)
end
defp all_f(q, {:primary_intents_resource_inventoried_as_primary_accountable, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], r.primary_accountable_id in ^v)
end
defp all_f(q, {:or_primary_intents_resource_inventoried_as_primary_accountable, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], r.primary_accountable_id in ^v)
end
defp all_f(q, {:primary_intents_resource_inventoried_as_classified_as, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], fragment("? @> ?", r.classified_as, ^v))
end
defp all_f(q, {:or_primary_intents_resource_inventoried_as_classified_as, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], fragment("? @> ?", r.classified_as, ^v))
end
defp all_f(q, {:primary_intents_resource_inventoried_as_name, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], ilike(r.name, ^"%#{v}%"))
end
defp all_f(q, {:or_primary_intents_resource_inventoried_as_name, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], ilike(r.name, ^v))
end
defp all_f(q, {:primary_intents_resource_inventoried_as_id, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], r.id in ^v)
end
defp all_f(q, {:or_primary_intents_resource_inventoried_as_id, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], r.id in ^v)
end

# join primary_intents
@spec join(Queryable.t(), atom()) :: Queryable.t()
defp join(q, :primary_intents) do
	if has_named_binding?(q, :primary_intents),
		do: q,
		else: join(q, :inner, [x], pi in assoc(x, :primary_intents), as: :primary_intents)
end
# join resource_inventoried_as through primary_intents above
defp join(q, :primary_intents_resource_inventoried_as) do
	q = join(q, :primary_intents)
	if has_named_binding?(q, :primary_intents_resource_inventoried_as),
		do: q,
		else: join(q, :inner, [primary_intents: pi], r in assoc(pi, :resource_inventoried_as),
			as: :primary_intents_resource_inventoried_as)
end

@spec all_validate(Schema.params())
	:: {:ok, Changeset.data()} | {:error, Changeset.t()}
defp all_validate(params) do
	{%{}, %{
		primary_intents_resource_inventoried_as_conforms_to: {:array, ID},
		or_primary_intents_resource_inventoried_as_conforms_to: {:array, ID},
		primary_intents_resource_inventoried_as_primary_accountable: {:array, ID},
		or_primary_intents_resource_inventoried_as_primary_accountable: {:array, ID},
		primary_intents_resource_inventoried_as_classified_as: {:array, :string},
		or_primary_intents_resource_inventoried_as_classified_as: {:array, :string},
		primary_intents_resource_inventoried_as_name: :string,
		or_primary_intents_resource_inventoried_as_name: :string,
		primary_intents_resource_inventoried_as_id: {:array, ID},
		or_primary_intents_resource_inventoried_as_id: {:array, ID},
	}}
	|> Changeset.cast(params, ~w[
		primary_intents_resource_inventoried_as_conforms_to
		or_primary_intents_resource_inventoried_as_conforms_to
		primary_intents_resource_inventoried_as_primary_accountable
		or_primary_intents_resource_inventoried_as_primary_accountable
		primary_intents_resource_inventoried_as_classified_as
		or_primary_intents_resource_inventoried_as_classified_as
		primary_intents_resource_inventoried_as_name
		or_primary_intents_resource_inventoried_as_name
		primary_intents_resource_inventoried_as_id
		or_primary_intents_resource_inventoried_as_id
	]a)
	|> Validate.class(:primary_intents_resource_inventoried_as_conforms_to)
	|> Validate.class(:or_primary_intents_resource_inventoried_as_conforms_to)
	|> Validate.class(:primary_intents_resource_inventoried_as_primary_accountable)
	|> Validate.class(:or_primary_intents_resource_inventoried_as_primary_accountable)
	|> Validate.class(:primary_intents_resource_inventoried_as_classified_as)
	|> Validate.class(:or_primary_intents_resource_inventoried_as_classified_as)
	|> Validate.name(:primary_intents_resource_inventoried_as_name)
	|> Validate.name(:or_primary_intents_resource_inventoried_as_name)
	|> Validate.exist_nand([:primary_intents_resource_inventoried_as_conforms_to,
		:or_primary_intents_resource_inventoried_as_conforms_to])
	|> Validate.exist_nand([:primary_intents_resource_inventoried_as_primary_accountable,
		:or_primary_intents_resource_inventoried_as_primary_accountable])
	|> Validate.exist_nand([:primary_intents_resource_inventoried_as_classified_as,
		:or_primary_intents_resource_inventoried_as_classified_as])
	|> Validate.exist_nand([:primary_intents_resource_inventoried_as_name,
		:or_primary_intents_resource_inventoried_as_name])
	|> Validate.exist_nand([:primary_intents_resource_inventoried_as_id,
		:or_primary_intents_resource_inventoried_as_id])
	|> Validate.escape_like(:primary_intents_resource_inventoried_as_name)
	|> Validate.escape_like(:or_primary_intents_resource_inventoried)
	|> Changeset.apply_action(nil)
end
end
