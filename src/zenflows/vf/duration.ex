defmodule Zenflows.VF.Duration do
@moduledoc """
Represents an interval between two DateTime values.
"""

use Zenflows.DB.Schema

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
			case chgset(params) do
				%{valid?: true} = cset_dur ->
					cset
					|> Changeset.put_change(field_unit_type(key),
						Changeset.fetch_change!(cset_dur, :unit_type))
					|> Changeset.put_change(field_numeric_duration(key),
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
			strkey = Atom.to_string(key)
			case cset.params do
				# If, for example, `key` is
				# `:has_duration`, and it's set to `nil`,
				# this will set the associated fields to
				# `nil` as well.
				%{^strkey => nil} ->
					cset
					|> Changeset.force_change(field_unit_type(key), nil)
					|> Changeset.force_change(field_numeric_duration(key), nil)

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
		unit_type: Map.get(schema, field_unit_type(key)),
		numeric_duration: Map.get(schema, field_numeric_duration(key)),
	}}
end

@cast ~w[unit_type numeric_duration]a
@reqr @cast

@spec chgset(params()) :: Changeset.t()
defp chgset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.validate_number(:numeric_duration, greater_than_or_equal_to: 0)
end

@spec field_unit_type(atom()) :: atom()
defp field_unit_type(key) do
	String.to_existing_atom("#{key}_unit_type")
end

@spec field_numeric_duration(atom()) :: atom()
defp field_numeric_duration(key) do
	String.to_existing_atom("#{key}_numeric_duration")
end
end
