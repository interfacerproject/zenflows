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

defmodule Zenflows.VF.EconomicResource.Query do
@moduledoc false

import Ecto.Query

alias Ecto.{Changeset, Queryable}
alias Zenflows.DB.{ID, Page, Schema, Validate}
alias Zenflows.VF.{EconomicEvent, EconomicResource}

@spec all(Page.t()) :: {:ok, Queryable.t()} | {:error, Changeset.t()}
def all(%{filter: nil}), do: {:ok, EconomicResource}
def all(%{filter: params}) do
	with {:ok, filters} <- all_validate(params) do
		{:ok, Enum.reduce(filters, EconomicResource, &all_f(&2, &1))}
	end
end

@spec all_f(Queryable.t(), {atom(), term()}) :: Queryable.t()
defp all_f(q, {:classified_as, v}),
	do: where(q, [x], fragment("? @> ?", x.classified_as, ^v))
defp all_f(q, {:primary_accountable, v}),
	do: where(q, [x], x.primary_accountable_id in ^v)
defp all_f(q, {:custodian, v}),
	do: where(q, [x], x.custodian_id in ^v)
defp all_f(q, {:conforms_to, v}),
	do: where(q, [x], x.conforms_to_id in ^v)
defp all_f(q, {:gt_onhand_quantity_has_numerical_value, v}),
	do: where(q, [x], x.onhand_quantity_has_numerical_value > ^v)

@spec all_validate(Schema.params()) ::
	{:ok, Changeset.data()} | {:error, Changeset.t()}
defp all_validate(params) do
	{%{}, %{
		classified_as: {:array, :string},
		primary_accountable: {:array, ID},
		custodian: {:array, ID},
		conforms_to: {:array, ID},
		gt_onhand_quantity_has_numerical_value: :float,
	}}
	|> Changeset.cast(params, ~w[
		classified_as primary_accountable custodian conforms_to
		gt_onhand_quantity_has_numerical_value
	]a)
	|> Validate.class(:classified_as)
	|> Validate.class(:primary_accountable)
	|> Validate.class(:custodian)
	|> Validate.class(:conforms_to)
	|> Changeset.validate_number(:gt_onhand_quantity_has_numerical_value,
		greater_than_or_equal_to: 0)
	|> Changeset.apply_action(nil)
end

@spec previous(Schema.id()) :: Queryable.t()
def previous(id) do
	from e in EconomicEvent,
		or_where: not is_nil(e.output_of_id) and e.resource_inventoried_as_id == ^id,
		or_where: e.to_resource_inventoried_as_id == ^id,
		or_where: e.action_id in ["raise", "lower"] and e.resource_inventoried_as_id == ^id
end
end
