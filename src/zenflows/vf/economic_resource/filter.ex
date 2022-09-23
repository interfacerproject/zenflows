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

defmodule Zenflows.VF.EconomicResource.Filter do
@moduledoc "Filtering logic of EconomicResources."

use Zenflows.DB.Schema

import Ecto.Query

alias Ecto.Query
alias Zenflows.DB.{Filter, ID}
alias Zenflows.VF.{EconomicResource, Validate}

@type error() :: Filter.error()

@spec filter(Filter.params()) :: Filter.result()
def filter(params) do
	case chgset(params) do
		%{valid?: true, changes: c} ->
			{:ok, Enum.reduce(c, EconomicResource, &f(&2, &1))}
		%{valid?: false} = cset ->
			{:error, cset}
	end
end

@spec f(Query.t(), {atom(), term()}) :: Query.t()
defp f(q, {:classified_as, v}),
	do: where(q, [x], fragment("? @> ?", x.classified_as, ^v))
defp f(q, {:primary_accountable, v}),
	do: where(q, [x], x.primary_accountable_id in ^v)
defp f(q, {:custodian, v}),
	do: where(q, [x], x.custodian_id in ^v)
defp f(q, {:conforms_to, v}),
	do: where(q, [x], x.conforms_to_id in ^v)

embedded_schema do
	field :classified_as, {:array, :string}
	field :primary_accountable, {:array, ID}
	field :custodian, {:array, ID}
	field :conforms_to, {:array, ID}
end

@cast ~w[classified_as primary_accountable custodian conforms_to]a

@spec chgset(params()) :: Changeset.t()
defp chgset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @cast)
	|> Validate.class(:classified_as)
	|> Validate.class(:primary_accountable)
	|> Validate.class(:custodian)
	|> Validate.class(:conforms_to)
end
end
