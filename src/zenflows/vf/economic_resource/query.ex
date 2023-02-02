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
defp all_f(q, {:id, v}),
	do: where(q, [x], x.id in ^v)
defp all_f(q, {:or_id, v}),
	do: or_where(q, [x], x.id in ^v)
defp all_f(q, {:classified_as, v}),
	do: where(q, [x], fragment("? @> ?", x.classified_as, ^v))
defp all_f(q, {:or_classified_as, v}),
	do: or_where(q, [x], fragment("? @> ?", x.classified_as, ^v))
defp all_f(q, {:primary_accountable, v}),
	do: where(q, [x], x.primary_accountable_id in ^v)
defp all_f(q, {:or_primary_accountable, v}),
	do: or_where(q, [x], x.primary_accountable_id in ^v)
defp all_f(q, {:not_primary_accountable, v}),
	do: where(q, [x], x.primary_accountable_id not in ^v)
defp all_f(q, {:custodian, v}),
	do: where(q, [x], x.custodian_id in ^v)
defp all_f(q, {:or_custodian, v}),
	do: or_where(q, [x], x.custodian_id in ^v)
defp all_f(q, {:not_custodian, v}),
	do: where(q, [x], x.custodian_id not in ^v)
defp all_f(q, {:conforms_to, v}),
	do: where(q, [x], x.conforms_to_id in ^v)
defp all_f(q, {:or_conforms_to, v}),
	do: or_where(q, [x], x.conforms_to_id in ^v)
defp all_f(q, {:gt_onhand_quantity_has_numerical_value, v}),
	do: where(q, [x], x.onhand_quantity_has_numerical_value > ^v)
defp all_f(q, {:or_gt_onhand_quantity_has_numerical_value, v}),
	do: or_where(q, [x], x.onhand_quantity_has_numerical_value > ^v)
defp all_f(q, {:name, v}),
	do: where(q, [x], ilike(x.name, ^"%#{v}%"))
defp all_f(q, {:or_name, v}),
	do: or_where(q, [x], ilike(x.name, ^"%#{v}%"))
defp all_f(q, {:note, v}),
	do: where(q, [x], ilike(x.note, ^"%#{v}%"))
defp all_f(q, {:or_note, v}),
	do: or_where(q, [x], ilike(x.note, ^"%#{v}%"))
defp all_f(q, {:repo, v}),
	do: where(q, [x], x.repo == ^v)
defp all_f(q, {:or_repo, v}),
	do: or_where(q, [x], x.repo == ^v)

@spec all_validate(Schema.params()) ::
	{:ok, Changeset.data()} | {:error, Changeset.t()}
defp all_validate(params) do
	{%{}, %{
		id: {:array, ID},
		or_id: {:array, ID},
		classified_as: {:array, :string},
		or_classified_as: {:array, :string},
		primary_accountable: {:array, ID},
		or_primary_accountable: {:array, ID},
		not_primary_accountable: {:array, ID},
		custodian: {:array, ID},
		or_custodian: {:array, ID},
		not_custodian: {:array, ID},
		conforms_to: {:array, ID},
		or_conforms_to: {:array, ID},
		gt_onhand_quantity_has_numerical_value: :decimal,
		or_gt_onhand_quantity_has_numerical_value: :decimal,
		name: :string,
		or_name: :string,
		note: :string,
		or_note: :string,
		repo: :string,
		or_repo: :string,
	}}
	|> Changeset.cast(params, ~w[
		id or_id
		classified_as or_classified_as
		primary_accountable or_primary_accountable not_primary_accountable
		custodian or_custodian not_custodian
		conforms_to or_conforms_to
		gt_onhand_quantity_has_numerical_value
		or_gt_onhand_quantity_has_numerical_value
		name or_name note or_note repo or_repo
	]a)
	|> Validate.class(:id)
	|> Validate.class(:or_id)
	|> Validate.exist_nand([:id, :or_id])
	|> Validate.class(:classified_as)
	|> Validate.class(:or_classified_as)
	|> Validate.exist_nand([:classified_as, :or_classified_as])
	|> Validate.class(:primary_accountable)
	|> Validate.class(:or_primary_accountable)
	|> Validate.class(:not_primary_accountable)
	|> Validate.exist_nand([:primary_accountable, :or_primary_accountable])
	|> Validate.class(:custodian)
	|> Validate.class(:or_custodian)
	|> Validate.class(:not_custodian)
	|> Validate.exist_nand([:custodian, :or_custodian])
	|> Validate.class(:conforms_to)
	|> Validate.class(:or_conforms_to)
	|> Validate.exist_nand([:conforms_to, :or_conforms_to])
	|> Changeset.validate_number(:gt_onhand_quantity_has_numerical_value,
		greater_than_or_equal_to: 0)
	|> Changeset.validate_number(:or_gt_onhand_quantity_has_numerical_value,
		greater_than_or_equal_to: 0)
	|> Validate.exist_nand([
		:gt_onhand_quantity_has_numerical_value,
		:or_gt_onhand_quantity_has_numerical_value,
	])
	|> Validate.name(:name)
	|> Validate.name(:or_name)
	|> Validate.note(:note)
	|> Validate.note(:or_note)
	|> Validate.exist_nand([:name, :or_name])
	|> Validate.exist_nand([:note, :or_note])
	|> Validate.exist_nand([:repo, :or_repo])
	|> Validate.escape_like(:name)
	|> Validate.escape_like(:or_name)
	|> Validate.escape_like(:note)
	|> Validate.escape_like(:or_note)
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
