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

defmodule ZenflowsTest.File do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.File
alias Zenflows.VF.{
	EconomicEvent,
	EconomicResource,
	Intent,
	Organization,
	Person,
	RecipeResource,
	ResourceSpecification,
}

test "works on RecipeResource" do
	assert {:ok, %RecipeResource{} = rec_res} =
		RecipeResource.Domain.create(%{
			name: Factory.str("name"),
			images: [
				%{
					hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
					name: "aaaaaaaaaaaaaaa",
					description: "aaaaaaaa",
					mime_type: "aaaaaa",
					extension: "aaaaaaa",
					size: 42,
					signature: "aaaaaaaaaaaaaaaaaaaaaa",
					width: 42,
					height: 42,
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 42,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
					width: 42,
					height: 42,
				},
			],
		})

	assert [%File{}, %File{}] = rec_res.images
end

test "works on EconomicResource" do
	agent = Factory.insert!(:agent)
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	{:ok, %EconomicEvent{} = evt} =
		EconomicEvent.Domain.create(
			%{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				has_point_in_time: Factory.now(),
				resource_conforms_to_id: spec.id,
				resource_quantity: %{
					has_numerical_value: 1,
					has_unit_id: unit.id,
				},
			},
			%{
				name: Factory.str("name"),
				images: [
					%{
						hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
						name: "aaaaaaaaaaaaaaa",
						description: "aaaaaaaa",
						mime_type: "aaaaaa",
						extension: "aaaaaaa",
						size: 42,
						signature: "aaaaaaaaaaaaaaaaaaaaaa",
						width: 42,
						height: 42,
					},
					%{
						hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
						name: "bbbbbbbbbbbbbbb",
						description: "bbbbbbbb",
						mime_type: "bbbbbb",
						extension: "bbbbbbb",
						size: 42,
						signature: "bbbbbbbbbbbbbbbbbbbbbb",
						width: 42,
						height: 42,
					},
				],
			})

	evt = EconomicEvent.Domain.preload(evt, :resource_inventoried_as)
	res = EconomicResource.Domain.preload(evt.resource_inventoried_as, :images)

	[%File{}, %File{}] = res.images
end

test "works on Person Agent" do
	assert {:ok, %Person{} = per} =
		Person.Domain.create(%{
			name: Factory.str("name"),
			user: Factory.str("user"),
			email: "#{Factory.str("user")}@example.com",
			images: [
				%{
					hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
					name: "aaaaaaaaaaaaaaa",
					description: "aaaaaaaa",
					mime_type: "aaaaaa",
					extension: "aaaaaaa",
					size: 42,
					signature: "aaaaaaaaaaaaaaaaaaaaaa",
					width: 42,
					height: 42,
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 42,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
					width: 42,
					height: 42,
				},
			],
		})

	assert [%File{}, %File{}] = per.images
end

test "works on Organization Agent" do
	assert {:ok, %Organization{} = org} =
		Organization.Domain.create(%{
			name: Factory.str("name"),
			images: [
				%{
					hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
					name: "aaaaaaaaaaaaaaa",
					description: "aaaaaaaa",
					mime_type: "aaaaaa",
					extension: "aaaaaaa",
					size: 42,
					signature: "aaaaaaaaaaaaaaaaaaaaaa",
					width: 42,
					height: 42,
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 42,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
					width: 42,
					height: 42,
				},
			],
		})

	assert [%File{}, %File{}] = org.images
end

test "works on ResourceSpecification" do
	assert {:ok, %ResourceSpecification{} = spec} =
		ResourceSpecification.Domain.create(%{
			name: Factory.str("name"),
			images: [
				%{
					hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
					name: "aaaaaaaaaaaaaaa",
					description: "aaaaaaaa",
					mime_type: "aaaaaa",
					extension: "aaaaaaa",
					size: 42,
					signature: "aaaaaaaaaaaaaaaaaaaaaa",
					width: 42,
					height: 42,
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 42,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
					width: 42,
					height: 42,
				},
			],
		})

	assert [%File{}, %File{}] = spec.images
end

test "works on Intent" do
	assert {:ok, %Intent{} = int} =
		Intent.Domain.create(%{
			action_id: "raise",
			provider_id: Factory.insert!(:agent).id,
			images: [
				%{
					hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
					name: "aaaaaaaaaaaaaaa",
					description: "aaaaaaaa",
					mime_type: "aaaaaa",
					extension: "aaaaaaa",
					size: 42,
					signature: "aaaaaaaaaaaaaaaaaaaaaa",
					width: 42,
					height: 42,
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 42,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
					width: 42,
					height: 42,
				},
			],
		})

	assert [%File{}, %File{}] = int.images
end

test "doesn't work without a belongs_to field" do
	{:error, %Changeset{errors: errs}} =
		File.changeset(%File{}, %{
				hash: "asnotehusnatoheusntaoehusntaeohu",
				name: "satoehusnoaethu",
				description: "foobaour",
				mime_type: "foobar",
				extension: "jpeeeeg",
				size: 25,
				signature: "faaosnetuhaoenthuousth",
				width: 200,
				height: 300,
		})
		|> Repo.insert()
	assert Keyword.has_key?(errs, :general)
end
end
