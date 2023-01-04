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

defmodule ZenflowsTest.VF.Action do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.Action

defmodule Dummy do
use Ecto.Schema

alias Ecto.Changeset
alias Zenflows.VF.Action

embedded_schema do
	field :action_id, Action.ID
	field :action, :map, virtual: true
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
	Changeset.cast(schema, params, [:action_id])
end
end

setup do
	%{inserted: %Dummy{action_id: Factory.build(:action_id)}}
end

test "insert" do
	# doesn't work with invalid ids
	assert %Changeset{valid?: false, changes: %{}, errors: errs}
		= Dummy.changeset(%{action_id: "doesn't exists"})
	assert Keyword.has_key?(errs, :action_id)

	# works with all valid ids
	Enum.each(Action.ID.values(), fn x ->
		assert %Changeset{valid?: true, changes: %{action_id: ^x}, errors: []}
			= Dummy.changeset(%{action_id: x})
	end)
end

test "update", %{inserted: schema} do
	# doesn't work with invalid ids
	assert %Changeset{valid?: false, changes: %{}, errors: errs}
		= Dummy.changeset(schema, %{action_id: "doesn't exists"})
	assert Keyword.has_key?(errs, :action_id)

	# because if the values are the same, there won't be any change
	all = Enum.reject(Action.ID.values(), &(&1 == schema.action_id))
	# works with all valid ids
	Enum.each(all, fn x ->
		assert %Changeset{valid?: true, changes: %{action_id: ^x}, errors: []}
			= Dummy.changeset(schema, %{action_id: x})
	end)
end

test "preload", %{inserted: %{action_id: id} = schema} do
	assert %{action: %Action{id: ^id}} = Action.preload(schema, :action)
end
end
