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
@moduledoc "Filtering logic of Proposals."

use Zenflows.DB.Schema

import Ecto.Query

alias Ecto.Query
alias Zenflows.DB.{Filter, ID}
alias Zenflows.VF.{Proposal, Validate}

@type error() :: Filter.error()

@spec filter(Filter.params()) :: Filter.result()
def filter(params) do
	case chgset(params) do
		%{valid?: true, changes: c} ->
			{:ok, Enum.reduce(c, Proposal, &f(&2, &1))}
		%{valid?: false} = cset ->
			{:error, cset}
	end
end

@spec f(Query.t(), {atom(), term()}) :: Query.t()
defp f(q, {:primary_intents_resource_inventoried_as_conforms_to, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], r.conforms_to_id in ^v)
end
defp f(q, {:or_primary_intents_resource_inventoried_as_conforms_to, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], r.conforms_to_id in ^v)
end
defp f(q, {:primary_intents_resource_inventoried_as_primary_accountable, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], r.primary_accountable_id in ^v)
end
defp f(q, {:or_primary_intents_resource_inventoried_as_primary_accountable, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], r.primary_accountable_id in ^v)
end
defp f(q, {:primary_intents_resource_inventoried_as_classified_as, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], fragment("? @> ?", r.classified_as, ^v))
end
defp f(q, {:or_primary_intents_resource_inventoried_as_classified_as, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], fragment("? @> ?", r.classified_as, ^v))
end
defp f(q, {:primary_intents_resource_inventoried_as_name, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], ilike(r.name, ^"%#{Filter.escape_like(v)}%"))
end
defp f(q, {:or_primary_intents_resource_inventoried_as_name, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], ilike(r.name, ^"%#{Filter.escape_like(v)}%"))
end
defp f(q, {:primary_intents_resource_inventoried_as_id, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> where([primary_intents_resource_inventoried_as: r], r.id in ^v)
end
defp f(q, {:or_primary_intents_resource_inventoried_as_id, v}) do
	q
	|> join(:primary_intents_resource_inventoried_as)
	|> or_where([primary_intents_resource_inventoried_as: r], r.id in ^v)
end

# join primary_intents
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

embedded_schema do
	field :primary_intents_resource_inventoried_as_conforms_to, {:array, ID}
	field :or_primary_intents_resource_inventoried_as_conforms_to, {:array, ID}
	field :primary_intents_resource_inventoried_as_primary_accountable, {:array, ID}
	field :or_primary_intents_resource_inventoried_as_primary_accountable, {:array, ID}
	field :primary_intents_resource_inventoried_as_classified_as, {:array, :string}
	field :or_primary_intents_resource_inventoried_as_classified_as, {:array, :string}
	field :primary_intents_resource_inventoried_as_name, :string
	field :or_primary_intents_resource_inventoried_as_name, :string
	field :primary_intents_resource_inventoried_as_id, {:array, ID}
	field :or_primary_intents_resource_inventoried_as_id, {:array, ID}
end

@cast ~w[
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
]a

@spec chgset(params()) :: Changeset.t()
defp chgset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @cast)
	|> Validate.class(:primary_intents_resource_inventoried_as_conforms_to)
	|> Validate.class(:or_primary_intents_resource_inventoried_as_conforms_to)
	|> Validate.class(:primary_intents_resource_inventoried_as_primary_accountable)
	|> Validate.class(:or_primary_intents_resource_inventoried_as_primary_accountable)
	|> Validate.class(:primary_intents_resource_inventoried_as_classified_as)
	|> Validate.class(:or_primary_intents_resource_inventoried_as_classified_as)
	|> Validate.name(:primary_intents_resource_inventoried_as_name)
	|> Validate.name(:or_primary_intents_resource_inventoried_as_name)
	|> Filter.check_xor(:primary_intents_resource_inventoried_as_conforms_to,
		:or_primary_intents_resource_inventoried_as_conforms_to)
	|> Filter.check_xor(:primary_intents_resource_inventoried_as_primary_accountable,
		:or_primary_intents_resource_inventoried_as_primary_accountable)
	|> Filter.check_xor(:primary_intents_resource_inventoried_as_classified_as,
		:or_primary_intents_resource_inventoried_as_classified_as)
	|> Filter.check_xor(:primary_intents_resource_inventoried_as_name,
		:or_primary_intents_resource_inventoried_as_name)
	|> Filter.check_xor(:primary_intents_resource_inventoried_as_id,
		:or_primary_intents_resource_inventoried_as_id)
end
end
