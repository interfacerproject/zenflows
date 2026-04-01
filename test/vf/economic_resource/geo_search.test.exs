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

defmodule ZenflowsTest.VF.EconomicResource.GeoSearch do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.DB.Page
alias Zenflows.VF.EconomicResource.Domain

# Helper to create a SpatialThing at given coordinates
defp insert_spatial_thing!(lat, long) do
	Factory.insert!(:spatial_thing, %{
		lat: Decimal.from_float(lat),
		long: Decimal.from_float(long),
	})
end

# Helper to create an EconomicResource at a given location
defp insert_resource_at!(location) do
	agent = Factory.insert!(:agent)
	%{resource_inventoried_as_id: res_id} =
		Zenflows.VF.EconomicEvent.Domain.create!(%{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_classified_as: Factory.str_list("some uri"),
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_numerical_value: Factory.decimald(),
				has_unit_id: Factory.insert!(:unit).id,
			},
			has_point_in_time: Factory.now(),
			to_location_id: location.id,
		}, %{name: Factory.str("some name")})
	Domain.one!(res_id)
end

describe "geo search filter" do
	test "returns resources within the given radius" do
		# Rome, Italy (41.9028, 12.4964)
		rome = insert_spatial_thing!(41.9028, 12.4964)
		# Milan, Italy (45.4642, 9.1900) - ~480km from Rome
		milan = insert_spatial_thing!(45.4642, 9.1900)
		# Paris, France (48.8566, 2.3522) - ~1100km from Rome
		paris = insert_spatial_thing!(48.8566, 2.3522)

		res_rome = insert_resource_at!(rome)
		res_milan = insert_resource_at!(milan)
		_res_paris = insert_resource_at!(paris)

		# Search 500km around Rome: should find Rome and Milan but not Paris
		page = Page.new(%{filter: %{
			near_lat: "41.9028",
			near_long: "12.4964",
			near_distance_km: "500",
		}})
		{:ok, results} = Domain.all(page)
		result_ids = MapSet.new(results, & &1.id)

		assert MapSet.member?(result_ids, res_rome.id)
		assert MapSet.member?(result_ids, res_milan.id)
		refute MapSet.member?(result_ids, _res_paris.id)
	end

	test "returns only nearby resources with small radius" do
		# Rome
		rome = insert_spatial_thing!(41.9028, 12.4964)
		# Milan (~480km away)
		milan = insert_spatial_thing!(45.4642, 9.1900)

		res_rome = insert_resource_at!(rome)
		_res_milan = insert_resource_at!(milan)

		# Search 100km around Rome: should find only Rome
		page = Page.new(%{filter: %{
			near_lat: "41.9028",
			near_long: "12.4964",
			near_distance_km: "100",
		}})
		{:ok, results} = Domain.all(page)
		result_ids = MapSet.new(results, & &1.id)

		assert MapSet.member?(result_ids, res_rome.id)
		refute MapSet.member?(result_ids, _res_milan.id)
	end

	test "excludes resources without a location" do
		rome = insert_spatial_thing!(41.9028, 12.4964)
		res_rome = insert_resource_at!(rome)

		# Create a resource without location (standard factory)
		res_no_loc = Factory.insert!(:economic_resource)

		page = Page.new(%{filter: %{
			near_lat: "41.9028",
			near_long: "12.4964",
			near_distance_km: "50000",
		}})
		{:ok, results} = Domain.all(page)
		result_ids = MapSet.new(results, & &1.id)

		assert MapSet.member?(result_ids, res_rome.id)
		refute MapSet.member?(result_ids, res_no_loc.id)
	end

	test "validates all three geo params must be provided together" do
		page = Page.new(%{filter: %{
			near_lat: "41.9028",
			near_long: "12.4964",
		}})
		assert {:error, %Ecto.Changeset{}} = Domain.all(page)
	end

	test "validates lat range" do
		page = Page.new(%{filter: %{
			near_lat: "91.0",
			near_long: "12.0",
			near_distance_km: "100",
		}})
		assert {:error, %Ecto.Changeset{}} = Domain.all(page)
	end

	test "validates distance must be positive" do
		page = Page.new(%{filter: %{
			near_lat: "41.0",
			near_long: "12.0",
			near_distance_km: "0",
		}})
		assert {:error, %Ecto.Changeset{}} = Domain.all(page)
	end

	test "combines geo filter with other filters" do
		rome = insert_spatial_thing!(41.9028, 12.4964)
		res_rome = insert_resource_at!(rome)

		page = Page.new(%{filter: %{
			near_lat: "41.9028",
			near_long: "12.4964",
			near_distance_km: "100",
			name: res_rome.name,
		}})
		{:ok, results} = Domain.all(page)
		result_ids = MapSet.new(results, & &1.id)

		assert MapSet.member?(result_ids, res_rome.id)
	end
end
end
