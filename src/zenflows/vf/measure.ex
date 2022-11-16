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

defmodule Zenflows.VF.Measure do
@moduledoc """
Semantic meaning for measurements: binds a quantity to its measurement
unit.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema
alias Zenflows.VF.Unit
alias Decimal, as: D

@type t() :: %__MODULE__{
	has_unit_id: Zenflows.DB.ID.t(),
	has_numerical_value: D.decimal(),
}

@primary_key false
embedded_schema do
	belongs_to :has_unit, Unit
	field :has_numerical_value, :decimal
end

@doc """
The cast allows you to split the virtual map field into its appropriate
fields.  An example usage is demonstraited in `Zenflows.VF.RecipeProcess`
and `Zenflows.VF.ScenarioDefinition` modules.
"""
@spec cast(Changeset.t(), atom()) :: Changeset.t()
def cast(cset, key) do
	case Changeset.fetch_change(cset, key) do
		{:ok, params} ->
			case changeset(params) do
				%{valid?: true} = cset_meas ->
					cset
					|> Changeset.put_change(:"#{key}_has_unit_id",
						Changeset.fetch_change!(cset_meas, :has_unit_id))
					|> Changeset.put_change(:"#{key}_has_numerical_value",
						Changeset.fetch_change!(cset_meas, :has_numerical_value))
				cset_meas ->
					Changeset.traverse_errors(cset_meas, fn {msg, opts} ->
						Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
							opts |> Keyword.get(:"#{key}", key) |> to_string()
						end)
					end)
					|> Enum.reduce(cset, fn {field, msg}, acc ->
						Changeset.add_error(acc, key, "#{field}: #{msg}")
					end)
			end
		:error ->
			# Ecto seems to convert the params' keys to string
			# whether they were originally string or atom.
			strkey = "#{key}"
			case cset.params do
				# If the field `key` is set to `nil`,
				# this will set the associated fields to
				# `nil` as well.
				%{^strkey => nil} ->
					cset
					|> Changeset.force_change(:"#{key}_has_unit_id", nil)
					|> Changeset.force_change(:"#{key}_has_numerical_value", nil)
				_ ->
					cset
			end
	end
	|> case do
		# if not embedded schema, which doesn't allow `assoc_constraint/3`...
		%{data: %{__meta__: %Ecto.Schema.Metadata{}}} = cset ->
			Changeset.assoc_constraint(cset, :"#{key}_has_unit")
		# this case is most useful when testing, which you use emebedded schemas
		cset ->
			cset
	end
end

@doc """
Propagates the virtual map field `key` with the associated fields
as a %Measure{} struct.  Useful for GraphQL types as can be seen in
`Zenflows.VF.ScenarioDefinition.Type` and `Zenflows.VF.RecipeProcess.Type`.
"""
@spec preload(Schema.t(), atom()) :: Schema.t()
def preload(schema, key) do
	%{schema | key => %__MODULE__{
		has_unit_id: Map.get(schema, :"#{key}_has_unit_id"),
		has_numerical_value: Map.get(schema, :"#{key}_has_numerical_value"),
	}}
end

@cast ~w[has_unit_id has_numerical_value]a
@reqr @cast

@spec changeset(Schema.params()) :: Changeset.t()
defp changeset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.validate_number(:has_numerical_value, greater_than: 0)
end
end
