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

defmodule ZenflowsTest.VF.Duration do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset

defmodule Dummy do
use Ecto.Schema

alias Ecto.Changeset
alias Zenflows.VF.{Duration, TimeUnit}

embedded_schema do
	field :has_duration, :map, virtual: true
	field :has_duration_unit_type, TimeUnit
	field :has_duration_numeric_duration, :decimal
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
	|> Changeset.cast(params, [:has_duration])
	|> Duration.cast(:has_duration)
end
end

setup do
	%{
		params: %{
			unit_type: Factory.build(:time_unit),
			numeric_duration: Factory.decimal(),
		},
		inserted: %Dummy{
			has_duration_unit_type: Factory.build(:time_unit),
			has_duration_numeric_duration: Factory.decimal(),
		},
	}
end

test "insert", %{params: params} do
	# no changes when params is `%{}`
	assert %Changeset{valid?: true, changes: %{}} = Dummy.changeset(%{})

	# fields are nil when `:has_duration` is `nil`
	assert %Changeset{valid?: true, changes: chgs} = Dummy.changeset(%{has_duration: nil})
	assert chgs.has_duration_unit_type == nil
	assert chgs.has_duration_numeric_duration == nil

	# fields are properly set when `:has_duration` is properly set
	assert %Changeset{valid?: true, changes: chgs} = Dummy.changeset(%{has_duration: params})
	assert chgs.has_duration_unit_type == params.unit_type
	assert Decimal.eq?(chgs.has_duration_numeric_duration, params.numeric_duration)

	# when no fields are provided, no fields are set
	assert %Changeset{valid?: false, changes: chgs, errors: errs}
		= Dummy.changeset(%{has_duration: %{}})
	assert length(Keyword.get_values(errs, :has_duration)) == 2
	refute Map.has_key?(chgs, :has_duration_unit_type)
		or Map.has_key?(chgs, :has_duration_numeric_duration)

	# when `:unit_type` is `nil`, no fields are set
	assert %Changeset{valid?: false, changes: chgs, errors: errs}
		= Dummy.changeset(%{has_duration: %{unit_type: nil}})
	assert length(Keyword.get_values(errs, :has_duration)) == 2
	refute Map.has_key?(chgs, :has_duration_unit_type)
		or Map.has_key?(chgs, :has_duration_numeric_duration)

	# when `:numeric_duration` is `nil`, no fields are set
	assert %Changeset{valid?: false, changes: %{has_duration: _}, errors: errs}
		= Dummy.changeset(%{has_duration: %{numeric_duration: nil}})
	assert length(Keyword.get_values(errs, :has_duration)) == 2
	refute Map.has_key?(chgs, :has_duration_unit_type)
		or Map.has_key?(chgs, :has_duration_numeric_duration)

	# when both fields are `nil`, no fields are set
	assert %Changeset{valid?: false, changes: %{has_duration: _}, errors: errs}
		= Dummy.changeset(%{has_duration: %{unit_type: nil, numeric_duration: nil}})
	assert length(Keyword.get_values(errs, :has_duration)) == 2
	refute Map.has_key?(chgs, :has_duration_unit_type)
		or Map.has_key?(chgs, :has_duration_numeric_duration)
end

test "update", %{params:  params, inserted: schema} do
	# no changes when params is `%{}`
	assert %Changeset{valid?: true, changes: %{}} = Dummy.changeset(schema, %{})

	# fields are nil when `:has_duration` is `nil`
	assert %Changeset{valid?: true, changes: %{
		has_duration_unit_type: nil,
		has_duration_numeric_duration: nil,
	}} = Dummy.changeset(schema, %{has_duration: nil})

	# fields are changed when `:has_duration` is properly set
	assert %Changeset{valid?: true, changes: chgs}
		= Dummy.changeset(schema, %{has_duration: params})
	# since ecto won't change it if it is already there
	if schema.has_duration_unit_type != params.unit_type,
		do: assert chgs.has_duration_unit_type == params.unit_type
	assert Decimal.eq?(chgs.has_duration_numeric_duration, params.numeric_duration)

	# when no fields are provided, no fields are set
	assert %Changeset{valid?: false, changes: chgs, errors: errs}
		= Dummy.changeset(schema, %{has_duration: %{}})
	assert length(Keyword.get_values(errs, :has_duration)) == 2
	refute Map.has_key?(chgs, :has_duration_unit_type)
		or Map.has_key?(chgs, :has_duration_numeric_duration)

	# when `:unit_type` is `nil`, no fields are set
	assert %Changeset{valid?: false, changes: chgs, errors: errs}
		= Dummy.changeset(schema, %{has_duration: %{unit_type: nil}})
	assert length(Keyword.get_values(errs, :has_duration)) == 2
	refute Map.has_key?(chgs, :has_duration_unit_type)
		or Map.has_key?(chgs, :has_duration_numeric_duration)

	# when `:numeric_duration` is `nil`, no fields are set
	assert %Changeset{valid?: false, changes: %{has_duration: _}, errors: errs}
		= Dummy.changeset(schema, %{has_duration: %{numeric_duration: nil}})
	assert length(Keyword.get_values(errs, :has_duration)) == 2
	refute Map.has_key?(chgs, :has_duration_unit_type)
		or Map.has_key?(chgs, :has_duration_numeric_duration)

	# when both fields are `nil`, no fields are set
	assert %Changeset{valid?: false, changes: %{has_duration: _}, errors: errs}
		= Dummy.changeset(schema, %{has_duration: %{unit_type: nil, numeric_duration: nil}})
	assert length(Keyword.get_values(errs, :has_duration)) == 2
	refute Map.has_key?(chgs, :has_duration_unit_type)
		or Map.has_key?(chgs, :has_duration_numeric_duration)
end
end
