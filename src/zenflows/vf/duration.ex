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

defmodule Zenflows.VF.Duration do
@moduledoc """
Represents an interval between two DateTime values.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema
alias Zenflows.VF.TimeUnitEnum

@type t() :: %__MODULE__{
	unit_type: TimeUnitEnum.t(),
	numeric_duration: float(),
}

@primary_key false
embedded_schema do
	field :unit_type, TimeUnitEnum
	field :numeric_duration, :float
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
				%{valid?: true} = cset_dur ->
					cset
					|> Changeset.put_change(:"#{key}_unit_type",
						Changeset.fetch_change!(cset_dur, :unit_type))
					|> Changeset.put_change(:"#{key}_numeric_duration",
						Changeset.fetch_change!(cset_dur, :numeric_duration))
				cset_dur ->
					cset_dur.errors
					|> Enum.reduce(cset, fn {field, {msg, _opts}}, acc ->
						Changeset.add_error(acc, key, "#{field}: #{msg}")
					end)
			end
		:error ->
			# Ecto seems to convert the params' keys to string
			# whether they were originally string or atom.
			strkey = "#{key}"
			case cset.params do
				# If, for example, `key` is
				# `:has_duration`, and it's set to `nil`,
				# this will set the associated fields to
				# `nil` as well.
				%{^strkey => nil} ->
					cset
					|> Changeset.force_change(:"#{key}_unit_type", nil)
					|> Changeset.force_change(:"#{key}_numeric_duration", nil)
				_ ->
					cset
			end
	end
end

@doc """
Propagates the virtual map field `key` with the associated fields
as a %Duration{} struct.  Useful for GraphQL types as can be seen in
`Zenflows.VF.ScenarioDefinition.Type` and `Zenflows.VF.RecipeProcess.Type`.
"""
@spec preload(Schema.t(), atom()) :: Schema.t()
def preload(schema, key) do
	%{schema | key => %__MODULE__{
		unit_type: Map.get(schema, :"#{key}_unit_type"),
		numeric_duration: Map.get(schema, :"#{key}_numeric_duration"),
	}}
end

@cast ~w[unit_type numeric_duration]a
@reqr @cast

@spec changeset(Schema.params()) :: Changeset.t()
defp changeset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.validate_number(:numeric_duration, greater_than_or_equal_to: 0)
end
end
