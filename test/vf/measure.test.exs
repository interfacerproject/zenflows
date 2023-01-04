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

defmodule ZenflowsTest.VF.Measure do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.{Measure, Unit}

defmodule Dummy do
use Ecto.Schema

alias Ecto.Changeset
alias Zenflows.VF.{Measure, Unit}

embedded_schema do
	field :quantity, :map, virtual: true
	belongs_to :quantity_has_unit, Unit
	field :quantity_has_numerical_value, :decimal
end

def changeset(params) do
	%__MODULE__{}
	|> common(params)
	|> Map.put(:action, :insert)
end

def changeset(schema, params) do
	schema
	|> common(params)
	|> Map.put(:action, :update)
end

defp common(schema, params) do
	schema
	|> Changeset.cast(params, [:quantity])
	|> Measure.cast(:quantity)
end
end

setup do
	%{
		params: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.decimal(),
		},
		inserted: %Dummy{
			quantity_has_unit_id: Factory.insert!(:unit).id,
			quantity_has_numerical_value: Factory.decimal(),
		},
	}
end

test "insert", %{params: params} do
	# no changes when params is `%{}`
	assert %Changeset{valid?: true, changes: %{}} = Dummy.changeset(%{})

	# fields are nil when `:quantity` is `nil`
	assert %Changeset{valid?: true, changes: chgs} = Dummy.changeset(%{quantity: nil})
	assert chgs.quantity_has_unit_id == nil
	assert chgs.quantity_has_numerical_value == nil

	# fields are properly set when `:quantity` is properly set
	assert %Changeset{valid?: true, changes: chgs} = Dummy.changeset(%{quantity: params})
	assert chgs.quantity_has_unit_id == params.has_unit_id
	assert Decimal.eq?(chgs.quantity_has_numerical_value, params.has_numerical_value)

	# `:has_numerical_value` must be positive
	assert %Changeset{valid?: false, errors: errs}
		= Dummy.changeset(%{quantity: Map.put(params, :has_numerical_value, 0)})
	assert length(Keyword.get_values(errs, :quantity)) == 1
	assert %Changeset{valid?: false, errors: errs}
		= Dummy.changeset(%{quantity: Map.put(params, :has_numerical_value, -1)})
	assert length(Keyword.get_values(errs, :quantity)) == 1

	# when no fields are provided, no fields are set
	assert %Changeset{valid?: false, changes: chgs, errors: errs}
		= Dummy.changeset(%{quantity: %{}})
	assert length(Keyword.get_values(errs, :quantity)) == 2
	refute Map.has_key?(chgs, :quantity_has_unit_id)
		or Map.has_key?(chgs, :quantity_has_numerical_value)

	# when `:has_unit_id` is `nil`, no fields are set
	assert %Changeset{valid?: false, changes: chgs, errors: errs}
		= Dummy.changeset(%{quantity: %{has_unit_id: nil}})
	assert length(Keyword.get_values(errs, :quantity)) == 2
	refute Map.has_key?(chgs, :quantity_has_unit_id)
		or Map.has_key?(chgs, :quantity_has_numerical_value)

	# when `:has_numerical_value` is `nil`, no fields are set
	assert %Changeset{valid?: false, changes: %{quantity: _}, errors: errs}
		= Dummy.changeset(%{quantity: %{has_numerical_value: nil}})
	assert length(Keyword.get_values(errs, :quantity)) == 2
	refute Map.has_key?(chgs, :quantity_has_unit_id)
		or Map.has_key?(chgs, :quantity_has_numerical_value)

	# when both fields are `nil`, no fields are set
	assert %Changeset{valid?: false, changes: %{quantity: _}, errors: errs}
		= Dummy.changeset(%{quantity: %{has_unit_id: nil, has_numerical_value: nil}})
	assert length(Keyword.get_values(errs, :quantity)) == 2
	refute Map.has_key?(chgs, :quantity_has_unit_id)
		or Map.has_key?(chgs, :quantity_has_numerical_value)
end

test "update", %{params:  params, inserted: schema} do
	# no changes when params is `%{}`
	assert %Changeset{valid?: true, changes: %{}} = Dummy.changeset(schema, %{})

	# fields are nil when `:quantity` is `nil`
	assert %Changeset{valid?: true, changes: %{
		quantity_has_unit_id: nil,
		quantity_has_numerical_value: nil,
	}} = Dummy.changeset(schema, %{quantity: nil})

	# fields are changed when `:quantity` is properly set
	assert %Changeset{valid?: true, changes: chgs}
		= Dummy.changeset(schema, %{quantity: params})
	assert chgs.quantity_has_unit_id == params.has_unit_id
	assert Decimal.eq?(chgs.quantity_has_numerical_value, params.has_numerical_value)

	# `:has_numerical_value` must be positive
	assert %Changeset{valid?: false, errors: errs}
		= Dummy.changeset(schema, %{quantity: Map.put(params, :has_numerical_value, 0)})
	assert length(Keyword.get_values(errs, :quantity)) == 1
	assert %Changeset{valid?: false, errors: errs}
		= Dummy.changeset(schema, %{quantity: Map.put(params, :has_numerical_value, -1)})
	assert length(Keyword.get_values(errs, :quantity)) == 1

	# when no fields are provided, no fields are set
	assert %Changeset{valid?: false, changes: chgs, errors: errs}
		= Dummy.changeset(schema, %{quantity: %{}})
	assert length(Keyword.get_values(errs, :quantity)) == 2
	refute Map.has_key?(chgs, :quantity_has_unit_id)
		or Map.has_key?(chgs, :quantity_has_numerical_value)

	# when `:has_unit_id` is `nil`, no fields are set
	assert %Changeset{valid?: false, changes: chgs, errors: errs}
		= Dummy.changeset(schema, %{quantity: %{has_unit_id: nil}})
	assert length(Keyword.get_values(errs, :quantity)) == 2
	refute Map.has_key?(chgs, :quantity_has_unit_id)
		or Map.has_key?(chgs, :quantity_has_numerical_value)

	# when `:has_numerical_value` is `nil`, no fields are set
	assert %Changeset{valid?: false, changes: %{quantity: _}, errors: errs}
		= Dummy.changeset(schema, %{quantity: %{has_numerical_value: nil}})
	assert length(Keyword.get_values(errs, :quantity)) == 2
	refute Map.has_key?(chgs, :quantity_has_unit_id)
		or Map.has_key?(chgs, :quantity_has_numerical_value)

	# when both fields are `nil`, no fields are set
	assert %Changeset{valid?: false, changes: %{quantity: _}, errors: errs}
		= Dummy.changeset(schema, %{quantity: %{has_unit_id: nil, has_numerical_value: nil}})
	assert length(Keyword.get_values(errs, :quantity)) == 2
	refute Map.has_key?(chgs, :quantity_has_unit_id)
		or Map.has_key?(chgs, :quantity_has_numerical_value)
end

test "preload", %{inserted: schema} do
	assert %{quantity: %Measure{} = meas} = Measure.preload(schema, :quantity)
	assert meas.has_unit_id == schema.quantity_has_unit_id
	assert meas.has_numerical_value == schema.quantity_has_numerical_value
end
end
