# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
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
	assert %RecipeResource{} = rec_res =
		RecipeResource.Domain.create!(%{
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
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 43,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
				},
			],
		})
		|> RecipeResource.Domain.preload(:images)
	assert [
		%{
			hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
			size: 42,
			bin: nil,
			name: "aaaaaaaaaaaaaaa",
			description: "aaaaaaaa",
			mime_type: "aaaaaa",
			extension: "aaaaaaa",
		},
		%{
			hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
			size: 43,
			bin: nil,
			name: "bbbbbbbbbbbbbbb",
			description: "bbbbbbbb",
			mime_type: "bbbbbb",
			extension: "bbbbbbb",
		},
	] = rec_res.images

	assert %RecipeResource{} = rec_res =
		RecipeResource.Domain.update!(rec_res.id, %{
			images: [
				%{
					hash: "cccccccccccccccc",
					name: "cccccccc",
					description: "cccc",
					mime_type: "ccc",
					extension: "cccc",
					size: 44,
					signature: "ccccccccccc",
				},
				%{
					hash: "dddddddddddddddddddddddddddddddd",
					name: "ddddddddddddddd",
					description: "dddddddd",
					mime_type: "dddddd",
					extension: "ddddddd",
					size: 45,
					signature: "dddddddddddddddddddddd",
				},
			],
		})
		|> RecipeResource.Domain.preload(:images)
	assert [
		%{
			hash: "cccccccccccccccc",
			size: 44,
			bin: nil,
			name: "cccccccc",
			description: "cccc",
			mime_type: "ccc",
			extension: "cccc",
		},
		%{
			hash: "dddddddddddddddddddddddddddddddd",
			size: 45,
			bin: nil,
			name: "ddddddddddddddd",
			description: "dddddddd",
			mime_type: "dddddd",
			extension: "ddddddd",
		},
	] = rec_res.images
end

test "works on EconomicResource" do
	agent = Factory.insert!(:agent)
	%EconomicResource{} = res =
		EconomicEvent.Domain.create!(
			%{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				has_point_in_time: Factory.now(),
				resource_conforms_to_id: Factory.insert!(:resource_specification).id,
				resource_quantity: %{
					has_numerical_value: 1,
					has_unit_id: Factory.insert!(:unit).id,
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
					},
					%{
						hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
						name: "bbbbbbbbbbbbbbb",
						description: "bbbbbbbb",
						mime_type: "bbbbbb",
						extension: "bbbbbbb",
						size: 43,
						signature: "bbbbbbbbbbbbbbbbbbbbbb",
					},
				],
			})
		|> EconomicEvent.Domain.preload(:resource_inventoried_as)
		|> Map.fetch!(:resource_inventoried_as)
		|> EconomicResource.Domain.preload(:images)
	assert [
		%{
			hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
			size: 42,
			bin: nil,
			name: "aaaaaaaaaaaaaaa",
			description: "aaaaaaaa",
			mime_type: "aaaaaa",
			extension: "aaaaaaa",
		},
		%{
			hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
			size: 43,
			bin: nil,
			name: "bbbbbbbbbbbbbbb",
			description: "bbbbbbbb",
			mime_type: "bbbbbb",
			extension: "bbbbbbb",
		},
	] = res.images

	assert %EconomicResource{} = res =
		EconomicResource.Domain.update!(res.id, %{
			images: [
				%{
					hash: "cccccccccccccccc",
					name: "cccccccc",
					description: "cccc",
					mime_type: "ccc",
					extension: "cccc",
					size: 44,
					signature: "ccccccccccc",
				},
				%{
					hash: "dddddddddddddddddddddddddddddddd",
					name: "ddddddddddddddd",
					description: "dddddddd",
					mime_type: "dddddd",
					extension: "ddddddd",
					size: 45,
					signature: "dddddddddddddddddddddd",
				},
			],
		})
		|> EconomicResource.Domain.preload(:images)
	assert [
		%{
			hash: "cccccccccccccccc",
			size: 44,
			bin: nil,
			name: "cccccccc",
			description: "cccc",
			mime_type: "ccc",
			extension: "cccc",
		},
		%{
			hash: "dddddddddddddddddddddddddddddddd",
			size: 45,
			bin: nil,
			name: "ddddddddddddddd",
			description: "dddddddd",
			mime_type: "dddddd",
			extension: "ddddddd",
		},
	] = res.images
end

test "works on Person Agent" do
	assert %Person{} = per =
		Person.Domain.create!(%{
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
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 43,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
				},
			],
		})
		|> Person.Domain.preload(:images)
	assert [
		%{
			hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
			size: 42,
			bin: nil,
			name: "aaaaaaaaaaaaaaa",
			description: "aaaaaaaa",
			mime_type: "aaaaaa",
			extension: "aaaaaaa",
		},
		%{
			hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
			size: 43,
			bin: nil,
			name: "bbbbbbbbbbbbbbb",
			description: "bbbbbbbb",
			mime_type: "bbbbbb",
			extension: "bbbbbbb",
		},
	] = per.images

	assert %Person{} = per =
		Person.Domain.update!(per.id, %{
			images: [
				%{
					hash: "cccccccccccccccc",
					name: "cccccccc",
					description: "cccc",
					mime_type: "ccc",
					extension: "cccc",
					size: 44,
					signature: "ccccccccccc",
				},
				%{
					hash: "dddddddddddddddddddddddddddddddd",
					name: "ddddddddddddddd",
					description: "dddddddd",
					mime_type: "dddddd",
					extension: "ddddddd",
					size: 45,
					signature: "dddddddddddddddddddddd",
				},
			],
		})
		|> Person.Domain.preload(:images)
	assert [
		%{
			hash: "cccccccccccccccc",
			size: 44,
			bin: nil,
			name: "cccccccc",
			description: "cccc",
			mime_type: "ccc",
			extension: "cccc",
		},
		%{
			hash: "dddddddddddddddddddddddddddddddd",
			size: 45,
			bin: nil,
			name: "ddddddddddddddd",
			description: "dddddddd",
			mime_type: "dddddd",
			extension: "ddddddd",
		},
	] = per.images
end

test "works on Organization Agent" do
	assert %Organization{} = org =
		Organization.Domain.create!(%{
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
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 43,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
				},
			],
		})
		|> Organization.Domain.preload(:images)
	assert [
		%{
			hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
			size: 42,
			bin: nil,
			name: "aaaaaaaaaaaaaaa",
			description: "aaaaaaaa",
			mime_type: "aaaaaa",
			extension: "aaaaaaa",
		},
		%{
			hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
			size: 43,
			bin: nil,
			name: "bbbbbbbbbbbbbbb",
			description: "bbbbbbbb",
			mime_type: "bbbbbb",
			extension: "bbbbbbb",
		},
	] = org.images

	assert %Organization{} = org =
		Organization.Domain.update!(org.id, %{
			images: [
				%{
					hash: "cccccccccccccccc",
					name: "cccccccc",
					description: "cccc",
					mime_type: "ccc",
					extension: "cccc",
					size: 44,
					signature: "ccccccccccc",
				},
				%{
					hash: "dddddddddddddddddddddddddddddddd",
					name: "ddddddddddddddd",
					description: "dddddddd",
					mime_type: "dddddd",
					extension: "ddddddd",
					size: 45,
					signature: "dddddddddddddddddddddd",
				},
			],
		})
		|> Organization.Domain.preload(:images)
	assert [
		%{
			hash: "cccccccccccccccc",
			size: 44,
			bin: nil,
			name: "cccccccc",
			description: "cccc",
			mime_type: "ccc",
			extension: "cccc",
		},
		%{
			hash: "dddddddddddddddddddddddddddddddd",
			size: 45,
			bin: nil,
			name: "ddddddddddddddd",
			description: "dddddddd",
			mime_type: "dddddd",
			extension: "ddddddd",
		},
	] = org.images
end

test "works on ResourceSpecification" do
	assert %ResourceSpecification{} = spec =
		ResourceSpecification.Domain.create!(%{
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
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 43,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
				},
			],
		})
		|> ResourceSpecification.Domain.preload(:images)
	assert [
		%{
			hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
			size: 42,
			bin: nil,
			name: "aaaaaaaaaaaaaaa",
			description: "aaaaaaaa",
			mime_type: "aaaaaa",
			extension: "aaaaaaa",
		},
		%{
			hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
			size: 43,
			bin: nil,
			name: "bbbbbbbbbbbbbbb",
			description: "bbbbbbbb",
			mime_type: "bbbbbb",
			extension: "bbbbbbb",
		},
	] = spec.images

	assert %ResourceSpecification{} = spec =
		ResourceSpecification.Domain.update!(spec.id, %{
			images: [
				%{
					hash: "cccccccccccccccc",
					name: "cccccccc",
					description: "cccc",
					mime_type: "ccc",
					extension: "cccc",
					size: 44,
					signature: "ccccccccccc",
				},
				%{
					hash: "dddddddddddddddddddddddddddddddd",
					name: "ddddddddddddddd",
					description: "dddddddd",
					mime_type: "dddddd",
					extension: "ddddddd",
					size: 45,
					signature: "dddddddddddddddddddddd",
				},
			],
		})
		|> ResourceSpecification.Domain.preload(:images)
	assert [
		%{
			hash: "cccccccccccccccc",
			size: 44,
			bin: nil,
			name: "cccccccc",
			description: "cccc",
			mime_type: "ccc",
			extension: "cccc",
		},
		%{
			hash: "dddddddddddddddddddddddddddddddd",
			size: 45,
			bin: nil,
			name: "ddddddddddddddd",
			description: "dddddddd",
			mime_type: "dddddd",
			extension: "ddddddd",
		},
	] = spec.images
end

test "works on Intent" do
	assert %Intent{} = int =
		Intent.Domain.create!(%{
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
				},
				%{
					hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
					name: "bbbbbbbbbbbbbbb",
					description: "bbbbbbbb",
					mime_type: "bbbbbb",
					extension: "bbbbbbb",
					size: 43,
					signature: "bbbbbbbbbbbbbbbbbbbbbb",
				},
			],
		})
		|> Intent.Domain.preload(:images)
	assert [
		%{
			hash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
			size: 42,
			bin: nil,
			name: "aaaaaaaaaaaaaaa",
			description: "aaaaaaaa",
			mime_type: "aaaaaa",
			extension: "aaaaaaa",
		},
		%{
			hash: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
			size: 43,
			bin: nil,
			name: "bbbbbbbbbbbbbbb",
			description: "bbbbbbbb",
			mime_type: "bbbbbb",
			extension: "bbbbbbb",
		},
	] = int.images

	assert %Intent{} = int =
		Intent.Domain.update!(int.id, %{
			images: [
				%{
					hash: "cccccccccccccccc",
					name: "cccccccc",
					description: "cccc",
					mime_type: "ccc",
					extension: "cccc",
					size: 44,
					signature: "ccccccccccc",
				},
				%{
					hash: "dddddddddddddddddddddddddddddddd",
					name: "ddddddddddddddd",
					description: "dddddddd",
					mime_type: "dddddd",
					extension: "ddddddd",
					size: 45,
					signature: "dddddddddddddddddddddd",
				},
			],
		})
		|> Intent.Domain.preload(:images)
	assert [
		%{
			hash: "cccccccccccccccc",
			size: 44,
			bin: nil,
			name: "cccccccc",
			description: "cccc",
			mime_type: "ccc",
			extension: "cccc",
		},
		%{
			hash: "dddddddddddddddddddddddddddddddd",
			size: 45,
			bin: nil,
			name: "ddddddddddddddd",
			description: "dddddddd",
			mime_type: "dddddd",
			extension: "ddddddd",
		},
	] = int.images
end
end
