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

defmodule ZenflowsTest.VF.EconomicEvent.Domain do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Ecto.Changeset
alias Zenflows.DB.Repo
alias Zenflows.VF.{
	EconomicEvent,
	EconomicEvent.Domain,
	EconomicResource,
	Process,
}

setup ctx do
	if ctx[:no_resource] do
		:ok
	else
		agent = Factory.insert!(:agent)
		params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}
		assert {:ok, _, res, _} = Domain.create(params, %{name: Factory.str("name")})

		if ctx[:want_contained] || ctx[:want_container] do
			agent = Factory.insert!(:agent)
			params = %{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				resource_conforms_to_id: Factory.insert!(:resource_specification).id,
				resource_quantity: %{
					has_unit_id: Factory.insert!(:unit).id,
					has_numerical_value: Factory.float(),
				},
				has_end: DateTime.utc_now(),
			}
			assert {:ok, _, tmp_res, _} = Domain.create(params, %{name: Factory.str("name")})

			# TODO: use combine-separate when implemented instead
			if ctx[:want_contained] do
				assert {:ok, _} = Changeset.change(res, contained_in_id: tmp_res.id) |> Repo.update()
			end

			if ctx[:want_container] do
				assert {:ok, _} = Changeset.change(tmp_res, contained_in_id: res.id) |> Repo.update()
			end
		end

		%{res: res}
	end
end

#@tag :skip
#test "by_id/1 returns a EconomicEvent" do
#	assert %EconomicEvent{} = Domain.by_id(eco_evt.id)
#end

describe "`create/2` with raise:" do
	setup ctx do
		if ctx[:no_resource] do
			:ok
		else
			res = ctx.res
			%{params: %{
				action_id: "raise",
				provider_id: res.primary_accountable_id,
				receiver_id: res.primary_accountable_id,
				resource_inventoried_as_id: res.id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: Factory.float(),
				},
				has_point_in_time: DateTime.utc_now(),
			}}
		end
	end

	@tag :no_resource
	test "pass with `:resource_conforms_to`" do
		agent = Factory.insert!(:agent)
		evt_params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
			to_location_id: Factory.insert!(:spatial_thing).id,
		}
		res_params = %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			image: Factory.img(),
			tracking_identifier: Factory.str("tracking identifier"),
			lot_id: Factory.insert!(:product_batch).id,
		}
		assert {:ok, %EconomicEvent{}, %EconomicResource{} = res, _} =
			Domain.create(evt_params, res_params)

		assert res.name == res_params.name
		assert res.note == res_params.note
		assert res.image == res_params.image
		assert res.tracking_identifier == res_params.tracking_identifier
		assert res.lot_id == res_params.lot_id

		assert res.primary_accountable_id == evt_params.receiver_id
		assert res.custodian_id == evt_params.receiver_id
		assert res.accounting_quantity_has_numerical_value == evt_params.resource_quantity.has_numerical_value
		assert res.accounting_quantity_has_unit_id == evt_params.resource_quantity.has_unit_id
		assert res.onhand_quantity_has_numerical_value == evt_params.resource_quantity.has_numerical_value
		assert res.onhand_quantity_has_unit_id == evt_params.resource_quantity.has_unit_id
		assert res.current_location_id == evt_params.to_location_id
	end

	test "pass with `:resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
	end

	test "fail when the agent doesn't have ownership over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have ownership over this resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource quantity must match with the unit of this resource"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't raise into a contained resource"} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container resource", %{params: params} do
		assert {:error, "you can't raise into a container resource"} = Domain.create(params, nil)
	end
end

describe "`create/2` with produce:" do
	setup ctx do
		if ctx[:no_resource] do
			:ok
		else
			res = ctx.res
			%{params: %{
				action_id: "produce",
				output_of_id: Factory.insert!(:process).id,
				provider_id: res.primary_accountable_id,
				receiver_id: res.primary_accountable_id,
				resource_inventoried_as_id: res.id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: Factory.float(),
				},
				has_beginning: DateTime.utc_now(),
			}}
		end
	end

	@tag :no_resource
	test "pass with `:resource_conforms_to`" do
		agent = Factory.insert!(:agent)
		evt_params = %{
			action_id: "produce",
			output_of_id: Factory.insert!(:process).id,
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
			to_location_id: Factory.insert!(:spatial_thing).id,
		}
		res_params = %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			image: Factory.img(),
			tracking_identifier: Factory.str("tracking identifier"),
			lot_id: Factory.insert!(:product_batch).id,
		}
		assert {:ok, %EconomicEvent{}, %EconomicResource{} = res, _} =
			Domain.create(evt_params, res_params)

		assert res.name == res_params.name
		assert res.note == res_params.note
		assert res.image == res_params.image
		assert res.tracking_identifier == res_params.tracking_identifier
		assert res.lot_id == res_params.lot_id

		assert res.primary_accountable_id == evt_params.receiver_id
		assert res.custodian_id == evt_params.receiver_id
		assert res.accounting_quantity_has_numerical_value == evt_params.resource_quantity.has_numerical_value
		assert res.accounting_quantity_has_unit_id == evt_params.resource_quantity.has_unit_id
		assert res.onhand_quantity_has_numerical_value == evt_params.resource_quantity.has_numerical_value
		assert res.onhand_quantity_has_unit_id == evt_params.resource_quantity.has_unit_id
		assert res.current_location_id == evt_params.to_location_id
	end

	test "pass with `:resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
	end

	test "fail when the agent doesn't have ownership over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have ownership over this resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource quantity must match with the unit of this resource"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't produce into a contained resource"} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container resource", %{params: params} do
		assert {:error, "you can't produce into a container resource"} = Domain.create(params, nil)
	end
end

describe "`create/2` with lower:" do
	setup %{res: res} do
		%{params: %{
			action_id: "lower",
			provider_id: res.primary_accountable_id,
			receiver_id: res.primary_accountable_id,
			resource_inventoried_as_id: res.id,
			resource_quantity: %{
				has_unit_id: res.accounting_quantity_has_unit_id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
	end

	test "fail when the agent doesn't have ownership over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have ownership over this resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource quantity must match with the unit of this resource"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't lower a contained resource"} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container resource", %{params: params} do
		assert {:error, "you can't lower a container resource"} = Domain.create(params, nil)
	end
end

describe "`create/2` with consume:" do
	setup %{res: res} do
		%{params: %{
			action_id: "consume",
			input_of_id: Factory.insert!(:process).id,
			provider_id: res.primary_accountable_id,
			receiver_id: res.primary_accountable_id,
			resource_inventoried_as_id: res.id,
			resource_quantity: %{
				has_unit_id: res.accounting_quantity_has_unit_id,
				has_numerical_value: Factory.float(),
			},
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
	end

	test "fail when the agent doesn't have ownership over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have ownership over this resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource quantity must match with the unit of this resource"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't consume a contained resource"} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container resource", %{params: params} do
		assert {:error, "you can't consume a container resource"} = Domain.create(params, nil)
	end
end

describe "`create/2` with use:" do
	setup %{res: res} do
		%{params: %{
			action_id: "use",
			input_of_id: Factory.insert!(:process).id,
			provider_id: Factory.insert!(:agent).id,
			receiver_id: Factory.insert!(:agent).id,
			resource_inventoried_as_id: res.id,
			resource_quantity: %{
				has_unit_id: res.accounting_quantity_has_unit_id,
				has_numerical_value: Factory.float(),
			},
			effort_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_point_in_time: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
	end

	test "fail when the event's resource quantity unit doesn't match with the resource's", %{params: params} do
		assert {:error, "the unit of resource quantity must match with the unit of this resource"} =
			update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
			|> Domain.create(nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't use a contained resource"} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container resource", %{params: params} do
		assert {:error, "you can't use a container resource"} = Domain.create(params, nil)
	end
end

describe "`create/2` with pickup:" do
	setup %{res: res} do
		%{params: %{
			action_id: "pickup",
			input_of_id: Factory.insert!(:process).id,
			provider_id: res.custodian_id,
			receiver_id: res.custodian_id,
			resource_inventoried_as_id: res.id,
			resource_quantity: %{
				has_unit_id: res.onhand_quantity_has_unit_id,
				has_numerical_value: res.onhand_quantity_has_numerical_value,
			},
			has_beginning: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
	end

	test "fail when provider doesn't have custody over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have custody over this resource"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't pickup a contained resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource quantity must match with the unit of this resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's quantity value and resource's onhand-quantity value differ", %{params: params} do
		params = update_in(params.resource_quantity.has_numerical_value, &(&1 + 1))
		assert {:error, "the pickup events need to fully pickup the resource"} =
			Domain.create(params, nil)
	end

	test "fail when more than one pickup event references the same resource in the same process", %{params: params} do
		assert {:ok, _} = Domain.create(params, nil)
		assert {:error, "no more than one pickup event in the same process, referring to the same resource is allowed"}
			= Domain.create(params, nil)
	end
end

describe "`create/2` with dropoff:" do
	setup %{res: res} do
		assert {:ok, pair_evt} = Domain.create(%{
			action_id: "pickup",
			input_of_id: Factory.insert!(:process).id,
			provider_id: res.custodian_id,
			receiver_id: res.custodian_id,
			resource_inventoried_as_id: res.id,
			resource_quantity: %{
				has_unit_id: res.onhand_quantity_has_unit_id,
				has_numerical_value: res.onhand_quantity_has_numerical_value,
			},
			has_end: DateTime.utc_now(),
		}, nil)

		%{params: %{
			action_id: "dropoff",
			output_of_id: pair_evt.input_of_id,
			provider_id: pair_evt.provider_id,
			receiver_id: pair_evt.receiver_id,
			resource_inventoried_as_id: pair_evt.resource_inventoried_as_id,
			resource_quantity: %{
				has_unit_id: pair_evt.resource_quantity_has_unit_id,
				has_numerical_value: pair_evt.resource_quantity_has_numerical_value,
			},
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
			to_location_id: Factory.insert!(:spatial_thing).id,
		}}
	end

	test "pass when all good", %{params: params} do
		assert {:ok, %EconomicEvent{} = evt} = Domain.create(params, nil)
		res = EconomicResource.Domain.by_id(evt.resource_inventoried_as_id)
		assert res.current_location_id == params.to_location_id
	end

	test "fail when provider doesn't have custody over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have custody over this resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and paired event's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource quantity must match with the unit of the paired event"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container and event's quantity value and resource's onhand-quantity value differ", %{params: params} do
		params = update_in(params.resource_quantity.has_numerical_value, &(&1 + 1))
		assert {:error, "the dropoff events need to fully dropoff the resource"} =
			Domain.create(params, nil)
	end

	test "fail when more than one dropoff event references the same resource in the same process", %{params: params} do
		assert {:ok, _} = Domain.create(params, nil)
		assert {:error, "no more than one dropoff event in the same process, referring to the same resource is allowed"}
			= Domain.create(params, nil)
	end
end

describe "`create/2` with accept:" do
	setup %{res: res} do
		%{params: %{
			action_id: "accept",
			input_of_id: Factory.insert!(:process).id,
			provider_id: res.custodian_id,
			receiver_id: res.custodian_id,
			resource_inventoried_as_id: res.id,
			resource_quantity: %{
				has_unit_id: res.onhand_quantity_has_unit_id,
				has_numerical_value: res.onhand_quantity_has_numerical_value,
			},
			has_point_in_time: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
	end

	test "fail when provider doesn't have custody over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have custody over this resource"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't accept a contained resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource quantity must match with the unit of this resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's quantity value and resource's onhand-quantity value differ", %{params: params} do
		params = update_in(params.resource_quantity.has_numerical_value, &(&1 + 1))
		assert {:error, "the accept events need to fully accept the resource"} =
			Domain.create(params, nil)
	end

	@tag skip: "TODO: use combine-separate when implemented"
	@tag :want_combine
	test "fail when the there are any combine events", %{params: params} do
		assert {:error, "you can't add another accept event to the same process where there are at least one combine or separate events"} =
			Domain.create(params, nil)
	end

	@tag skip: "TODO: use combine-separate when implemented"
	@tag :want_combine
	test "fail when the there are any separate events", %{params: params} do
		assert {:error, "you can't add another accept event to the same process where there are at least one combine or separate events"} =
			Domain.create(params, nil)
	end

	test "fail when more than one accept event references the same resource in the same process", %{params: params} do
		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)

		# in order to satisfy the fact that they it should fully
		# accept the resource
		params
		|> Map.put(:action_id, "raise")
		|> Domain.create(nil)
		assert {:error, "no more than one accept event in the same process, referring to the same resource is allowed"} =
			Domain.create(params, nil)
	end
end

describe "`create/2` with modify:" do
	setup %{res: res} do
		assert {:ok, pair_evt} = Domain.create(%{
			action_id: "accept",
			input_of_id: Factory.insert!(:process).id,
			provider_id: res.custodian_id,
			receiver_id: res.custodian_id,
			resource_inventoried_as_id: res.id,
			resource_quantity: %{
				has_unit_id: res.onhand_quantity_has_unit_id,
				has_numerical_value: res.onhand_quantity_has_numerical_value,
			},
			has_end: DateTime.utc_now(),
		}, nil)

		%{params: %{
			action_id: "modify",
			output_of_id: pair_evt.input_of_id,
			provider_id: pair_evt.provider_id,
			receiver_id: pair_evt.receiver_id,
			resource_inventoried_as_id: pair_evt.resource_inventoried_as_id,
			resource_quantity: %{
				has_unit_id: pair_evt.resource_quantity_has_unit_id,
				has_numerical_value: pair_evt.resource_quantity_has_numerical_value,
			},
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		assert res_before.stage_id == nil

		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		proc = Process.Domain.by_id(params.output_of_id)
		assert res_after.stage_id == proc.based_on_id
		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
	end

	test "fail when provider doesn't have custody over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have custody over this resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and paired event's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ ->
			Factory.insert!(:unit).id
		end)
		assert {:error, "the unit of resource quantity must match with the unit of the paired event"} =
			Domain.create(params, nil)
	end

	test "fail when event's quantity value and resource's onhand-quantity value differ", %{params: params} do
		params = update_in(params.resource_quantity.has_numerical_value, &(&1 + 1))
		assert {:error, "the modify events need to fully modify the resource"} =
			Domain.create(params, nil)
	end

	test "fail when more than one modify event references the same resource in the same process", %{params: params} do
		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)

		# in order to satisfy the fact that they it should fully
		# modify the resource
		params
		|> Map.put(:action_id, "raise")
		|> Domain.create(nil)
		assert {:error, "no more than one modify event in the same process, referring to the same resource is allowed"} =
			Domain.create(params, nil)
	end
end

describe "`create/2` with transferCustody:" do
	setup %{res: res} = ctx do
		if ctx[:want_to_resource] do
			agent = Factory.insert!(:agent)
			params = %{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				resource_conforms_to_id: res.conforms_to_id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: Factory.float(),
				},
				has_point_in_time: DateTime.utc_now(),
			}
			assert {:ok, _, to_res, _} = Domain.create(params, %{name: Factory.str("name")})

			%{params: %{
				action_id: "transferCustody",
				provider_id: res.custodian_id,
				receiver_id: Factory.insert!(:agent).id,
				resource_inventoried_as_id: res.id,
				to_resource_inventoried_as_id: to_res.id,
				resource_quantity: %{
					has_unit_id: res.onhand_quantity_has_unit_id,
					has_numerical_value: res.onhand_quantity_has_numerical_value,
				},
				has_beginning: DateTime.utc_now(),
			}}
		else
			%{params: %{
				action_id: "transferCustody",
				provider_id: res.custodian_id,
				receiver_id: Factory.insert!(:agent).id,
				resource_inventoried_as_id: res.id,
				resource_quantity: %{
					has_unit_id: res.onhand_quantity_has_unit_id,
					has_numerical_value: res.onhand_quantity_has_numerical_value,
				},
				to_location_id: Factory.insert!(:spatial_thing).id,
				has_beginning: DateTime.utc_now(),
			}}
		end
	end

	test "pass without `:to_resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		contained_ids = Enum.map(0..9, fn _ ->
			agent = Factory.insert!(:agent)
			raise_params = %{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				resource_conforms_to_id: Factory.insert!(:resource_specification).id,
				resource_quantity: %{
					has_unit_id: Factory.insert!(:unit).id,
					has_numerical_value: Factory.float(),
				},
				has_end: DateTime.utc_now(),
			}
			assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
			assert {:ok, _} =
				Changeset.change(tmp_res, contained_in_id: params.resource_inventoried_as_id) |> Repo.update()

			tmp_res.id
		end)

		res_params = %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			image: Factory.img(),
			tracking_identifier: Factory.str("tracking identifier"),
			lot_id: Factory.insert!(:product_batch).id,
		}
		assert {:ok, %EconomicEvent{} = evt, _, %EconomicResource{} = to_res} = Domain.create(params, res_params)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value - params.resource_quantity.has_numerical_value

		assert to_res.name == res_params.name
		assert to_res.note == res_params.note
		assert to_res.image == res_params.image
		assert to_res.tracking_identifier == res_params.tracking_identifier
		assert to_res.lot_id == res_params.lot_id

		assert to_res.primary_accountable_id == params.receiver_id
		assert to_res.custodian_id == params.receiver_id
		assert to_res.accounting_quantity_has_numerical_value == 0
		assert to_res.accounting_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert to_res.onhand_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert to_res.onhand_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert to_res.current_location_id == params.to_location_id

		from(r in EconomicResource,
			where: r.id in ^contained_ids,
			select: map(r, ~w[custodian_id contained_in_id]a))
		|> Repo.all()
		|> Enum.each(fn r ->
			assert r.custodian_id == evt.receiver_id
			assert r.contained_in_id == to_res.id
		end)
	end

	@tag :want_to_resource
	test "pass with `:to_resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		to_res_before = EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)

		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		to_res_after = EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value - params.resource_quantity.has_numerical_value

		assert to_res_after.accounting_quantity_has_numerical_value ==
			to_res_before.accounting_quantity_has_numerical_value
		assert to_res_after.onhand_quantity_has_numerical_value ==
			to_res_before.onhand_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
	end

	test "fail when provider doesn't have custody over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have custody over this resource"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't transfer-custody a contained resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource-quantity must match with the unit of resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container and onhand-quantity is non-positive", %{params: params} do
		err = "the transfer-custody events need container resources to have positive onhand-quantity"
		res = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		Changeset.change(res, onhand_quantity_has_numerical_value: 0.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)

		Changeset.change(res, onhand_quantity_has_numerical_value: -1.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when event's quantity value and resource's onhand-quantity value differ", %{params: params} do
		params = update_in(params.resource_quantity.has_numerical_value, &(&1 + 1))
		assert {:error, "the transfer-custody events need to fully transfer the resource"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	@tag :want_to_resource
	test "fail when transferring a container resource into another resource", %{params: params} do
		assert {:error, "you can't transfer-custody a container resource into another resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when the to-resource is a contained resource", %{params: params} do
		agent = Factory.insert!(:agent)
		raise_params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}
		assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
		# TODO: use combine-separate when implemented instead
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(contained_in_id: tmp_res.id)
		|> Repo.update!()

		assert {:error, "you can't transfer-custody into a contained resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when the to-resource is a container resource", %{params: params} do
		agent = Factory.insert!(:agent)
		raise_params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}
		assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
		# TODO: use combine-separate when implemented instead
		Changeset.change(tmp_res, contained_in_id: params.to_resource_inventoried_as_id)
		|> Repo.update()

		assert {:error, "you can't transfer-custody into a container resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when event's unit and to-resource's unit differ", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(onhand_quantity_has_unit_id: Factory.insert!(:unit).id)
		|> Repo.update!()

		assert {:error, "the unit of resource-quantity must match with the unit of to-resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when resoure and to-resource don't conform to the same spec", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(conforms_to_id: Factory.insert!(:resource_specification).id)
		|> Repo.update!()

		assert {:error, "the resources must conform to the same specification"} =
			Domain.create(params, nil)
	end
end

describe "`create/2` with transferAllRights:" do
	setup %{res: res} = ctx do
		if ctx[:want_to_resource] do
			agent = Factory.insert!(:agent)
			params = %{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				resource_conforms_to_id: res.conforms_to_id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: Factory.float(),
				},
				has_point_in_time: DateTime.utc_now(),
			}
			assert {:ok, _, to_res, _} = Domain.create(params, %{name: Factory.str("name")})

			%{params: %{
				action_id: "transferAllRights",
				provider_id: res.primary_accountable_id,
				receiver_id: Factory.insert!(:agent).id,
				resource_inventoried_as_id: res.id,
				to_resource_inventoried_as_id: to_res.id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: res.accounting_quantity_has_numerical_value,
				},
				has_beginning: DateTime.utc_now(),
			}}
		else
			%{params: %{
				action_id: "transferAllRights",
				provider_id: res.primary_accountable_id,
				receiver_id: Factory.insert!(:agent).id,
				resource_inventoried_as_id: res.id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: res.accounting_quantity_has_numerical_value,
				},
				has_beginning: DateTime.utc_now(),
			}}
		end
	end

	test "pass without `:to_resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		contained_ids = Enum.map(0..9, fn _ ->
			agent = Factory.insert!(:agent)
			raise_params = %{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				resource_conforms_to_id: Factory.insert!(:resource_specification).id,
				resource_quantity: %{
					has_unit_id: Factory.insert!(:unit).id,
					has_numerical_value: Factory.float(),
				},
				has_end: DateTime.utc_now(),
			}
			assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
			assert {:ok, _} =
				Changeset.change(tmp_res, contained_in_id: params.resource_inventoried_as_id) |> Repo.update()

			tmp_res.id
		end)

		res_params = %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			image: Factory.img(),
			tracking_identifier: Factory.str("tracking identifier"),
			lot_id: Factory.insert!(:product_batch).id,
		}
		assert {:ok, %EconomicEvent{} = evt, _, %EconomicResource{} = to_res} = Domain.create(params, res_params)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value

		assert to_res.name == res_params.name
		assert to_res.note == res_params.note
		assert to_res.image == res_params.image
		assert to_res.tracking_identifier == res_params.tracking_identifier
		assert to_res.lot_id == res_params.lot_id

		assert to_res.primary_accountable_id == params.receiver_id
		assert to_res.custodian_id == params.receiver_id
		assert to_res.accounting_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert to_res.accounting_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert to_res.onhand_quantity_has_numerical_value == 0
		assert to_res.onhand_quantity_has_unit_id == params.resource_quantity.has_unit_id

		from(r in EconomicResource,
			where: r.id in ^contained_ids,
			select: map(r, ~w[primary_accountable_id contained_in_id]a))
		|> Repo.all()
		|> Enum.each(fn r ->
			assert r.primary_accountable_id == evt.receiver_id
			assert r.contained_in_id == to_res.id
		end)
	end

	@tag :want_to_resource
	test "pass with `:to_resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		to_res_before = EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)

		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		to_res_after = EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value

		assert to_res_after.accounting_quantity_has_numerical_value ==
			to_res_before.accounting_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
		assert to_res_after.onhand_quantity_has_numerical_value ==
			to_res_before.onhand_quantity_has_numerical_value
	end

	test "fail when provider doesn't have accountability over the resource", %{params: params} do
		agent = Factory.insert!(:agent)
		params =
			params
			|> Map.put(:provider_id, agent.id)
			|> Map.put(:receiver_id, agent.id)
		assert {:error, "you don't have accountability over this resource"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't transfer-all-rights a contained resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource-quantity must match with the unit of resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container and accounting-quantity is non-positive", %{params: params} do
		err = "the transfer-all-rights events need container resources to have positive accounting-quantity"
		res = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		Changeset.change(res, accounting_quantity_has_numerical_value: 0.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)

		Changeset.change(res, accounting_quantity_has_numerical_value: -1.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when event's quantity value and resource's accounting-quantity value differ", %{params: params} do
		params = update_in(params.resource_quantity.has_numerical_value, &(&1 + 1))
		assert {:error, "the transfer-all-rights events need to fully transfer the resource"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	@tag :want_to_resource
	test "fail when transferring a container resource into another resource", %{params: params} do
		assert {:error, "you can't transfer-all-rights a container resource into another resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when the to-resource is a contained resource", %{params: params} do
		agent = Factory.insert!(:agent)
		raise_params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}
		assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
		# TODO: use combine-separate when implemented instead
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(contained_in_id: tmp_res.id)
		|> Repo.update!()

		assert {:error, "you can't transfer-all-rights into a contained resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when the to-resource is a container resource", %{params: params} do
		agent = Factory.insert!(:agent)
		raise_params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}
		assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
		# TODO: use combine-separate when implemented instead
		Changeset.change(tmp_res, contained_in_id: params.to_resource_inventoried_as_id)
		|> Repo.update()

		assert {:error, "you can't transfer-all-rights into a container resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when event's unit and to-resource's unit differ", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(accounting_quantity_has_unit_id: Factory.insert!(:unit).id)
		|> Repo.update!()

		assert {:error, "the unit of resource-quantity must match with the unit of to-resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when resoure and to-resource don't conform to the same spec", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(conforms_to_id: Factory.insert!(:resource_specification).id)
		|> Repo.update!()

		assert {:error, "the resources must conform to the same specification"} =
			Domain.create(params, nil)
	end
end

describe "`create/2` with transfer:" do
	setup %{res: res} = ctx do
		if ctx[:want_to_resource] do
			agent = Factory.insert!(:agent)
			params = %{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				resource_conforms_to_id: res.conforms_to_id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: Factory.float(),
				},
				has_point_in_time: DateTime.utc_now(),
			}
			assert {:ok, _, to_res, _} = Domain.create(params, %{name: Factory.str("name")})

			%{params: %{
				action_id: "transfer",
				provider_id: res.primary_accountable_id,
				receiver_id: Factory.insert!(:agent).id,
				resource_inventoried_as_id: res.id,
				to_resource_inventoried_as_id: to_res.id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: res.accounting_quantity_has_numerical_value,
				},
				has_beginning: DateTime.utc_now(),
			}}
		else
			%{params: %{
				action_id: "transfer",
				provider_id: res.primary_accountable_id,
				receiver_id: Factory.insert!(:agent).id,
				resource_inventoried_as_id: res.id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: res.accounting_quantity_has_numerical_value,
				},
				has_beginning: DateTime.utc_now(),
			}}
		end
	end

	test "pass without `:to_resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		contained_ids = Enum.map(0..9, fn _ ->
			agent = Factory.insert!(:agent)
			raise_params = %{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				resource_conforms_to_id: Factory.insert!(:resource_specification).id,
				resource_quantity: %{
					has_unit_id: Factory.insert!(:unit).id,
					has_numerical_value: Factory.float(),
				},
				has_end: DateTime.utc_now(),
			}
			assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
			assert {:ok, _} =
				Changeset.change(tmp_res, contained_in_id: params.resource_inventoried_as_id) |> Repo.update()

			tmp_res.id
		end)

		res_params = %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			image: Factory.img(),
			tracking_identifier: Factory.str("tracking identifier"),
			lot_id: Factory.insert!(:product_batch).id,
		}
		assert {:ok, %EconomicEvent{} = evt, _, %EconomicResource{} = to_res} = Domain.create(params, res_params)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value - params.resource_quantity.has_numerical_value

		assert to_res.name == res_params.name
		assert to_res.note == res_params.note
		assert to_res.image == res_params.image
		assert to_res.tracking_identifier == res_params.tracking_identifier
		assert to_res.lot_id == res_params.lot_id

		assert to_res.primary_accountable_id == params.receiver_id
		assert to_res.custodian_id == params.receiver_id
		assert to_res.accounting_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert to_res.accounting_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert to_res.onhand_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert to_res.onhand_quantity_has_unit_id == params.resource_quantity.has_unit_id

		from(r in EconomicResource,
			where: r.id in ^contained_ids,
			select: map(r, ~w[primary_accountable_id custodian_id contained_in_id]a))
		|> Repo.all()
		|> Enum.each(fn r ->
			assert r.primary_accountable_id == evt.receiver_id
			assert r.custodian_id == evt.receiver_id
			assert r.contained_in_id == to_res.id
		end)
	end

	@tag :want_to_resource
	test "pass with `:to_resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		to_res_before = EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)

		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		to_res_after = EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value - params.resource_quantity.has_numerical_value

		assert to_res_after.accounting_quantity_has_numerical_value ==
			to_res_before.accounting_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
		assert to_res_after.onhand_quantity_has_numerical_value ==
			to_res_before.onhand_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
	end

	test "fail when provider doesn't have accountability over the resource", %{params: params} do
		EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		|> Changeset.change(primary_accountable_id: Factory.insert!(:agent).id)
		|> Repo.update!()
		assert {:error, "you don't have accountability over this resource"} =
			Domain.create(params, nil)
	end

	test "fail when provider doesn't have custody over the resource", %{params: params} do
		EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		|> Changeset.change(custodian_id: Factory.insert!(:agent).id)
		|> Repo.update!()
		assert {:error, "you don't have custody over this resource"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't transfer a contained resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource-quantity must match with the unit of resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when event's unit and to-resource's unit differ", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(accounting_quantity_has_unit_id: Factory.insert!(:unit).id)
		|> Repo.update!()

		assert {:error, "the unit of resource-quantity must match with the unit of to-resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container and accounting-quantity is non-positive", %{params: params} do
		err = "the transfer events need container resources to have positive accounting-quantity"
		res = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		Changeset.change(res, accounting_quantity_has_numerical_value: 0.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)

		Changeset.change(res, accounting_quantity_has_numerical_value: -1.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container and onhand-quantity is non-positive", %{params: params} do
		err = "the transfer events need container resources to have positive onhand-quantity"
		res = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		Changeset.change(res, onhand_quantity_has_numerical_value: 0.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)

		Changeset.change(res, onhand_quantity_has_numerical_value: -1.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when event's quantity value and resource's accounting-quantity value differ", %{params: params} do
		EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		|> Changeset.change(accounting_quantity_has_numerical_value: params.resource_quantity.has_numerical_value + 1)
		|> Repo.update!()
		assert {:error, "the transfer events need to fully transfer the resource"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when event's quantity value and resource's onhnad-quantity value differ", %{params: params} do
		EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		|> Changeset.change(onhand_quantity_has_numerical_value: params.resource_quantity.has_numerical_value + 1)
		|> Repo.update!()
		assert {:error, "the transfer events need to fully transfer the resource"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	@tag :want_to_resource
	test "fail when transferring a container resource into another resource", %{params: params} do
		assert {:error, "you can't transfer a container resource into another resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when the to-resource is a contained resource", %{params: params} do
		agent = Factory.insert!(:agent)
		raise_params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}
		assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
		# TODO: use combine-separate when implemented instead
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(contained_in_id: tmp_res.id)
		|> Repo.update!()

		assert {:error, "you can't transfer into a contained resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when the to-resource is a container resource", %{params: params} do
		agent = Factory.insert!(:agent)
		raise_params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}
		assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
		# TODO: use combine-separate when implemented instead
		Changeset.change(tmp_res, contained_in_id: params.to_resource_inventoried_as_id)
		|> Repo.update()

		assert {:error, "you can't transfer into a container resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when resoure and to-resource don't conform to the same spec", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(conforms_to_id: Factory.insert!(:resource_specification).id)
		|> Repo.update!()

		assert {:error, "the resources must conform to the same specification"} =
			Domain.create(params, nil)
	end
end

describe "`create/2` with move:" do
	setup %{res: res} = ctx do
		if ctx[:want_to_resource] do
			params = %{
				action_id: "raise",
				provider_id: res.primary_accountable_id,
				receiver_id: res.custodian_id,
				resource_conforms_to_id: res.conforms_to_id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: Factory.float(),
				},
				has_point_in_time: DateTime.utc_now(),
			}
			assert {:ok, _, to_res, _} = Domain.create(params, %{name: Factory.str("name")})

			%{params: %{
				action_id: "move",
				provider_id: res.primary_accountable_id,
				receiver_id: res.custodian_id,
				resource_inventoried_as_id: res.id,
				to_resource_inventoried_as_id: to_res.id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: res.accounting_quantity_has_numerical_value,
				},
				has_beginning: DateTime.utc_now(),
			}}
		else
			%{params: %{
				action_id: "move",
				provider_id: res.primary_accountable_id,
				receiver_id: res.custodian_id,
				resource_inventoried_as_id: res.id,
				resource_quantity: %{
					has_unit_id: res.accounting_quantity_has_unit_id,
					has_numerical_value: res.accounting_quantity_has_numerical_value,
				},
				has_beginning: DateTime.utc_now(),
			}}
		end
	end

	test "pass without `:to_resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		contained_ids = Enum.map(0..9, fn _ ->
			agent = Factory.insert!(:agent)
			raise_params = %{
				action_id: "raise",
				provider_id: agent.id,
				receiver_id: agent.id,
				resource_conforms_to_id: Factory.insert!(:resource_specification).id,
				resource_quantity: %{
					has_unit_id: Factory.insert!(:unit).id,
					has_numerical_value: Factory.float(),
				},
				has_end: DateTime.utc_now(),
			}
			assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
			assert {:ok, _} =
				Changeset.change(tmp_res, contained_in_id: params.resource_inventoried_as_id) |> Repo.update()

			tmp_res.id
		end)

		res_params = %{
			name: Factory.str("name"),
			note: Factory.str("note"),
			image: Factory.img(),
			tracking_identifier: Factory.str("tracking identifier"),
			lot_id: Factory.insert!(:product_batch).id,
		}
		assert {:ok, %EconomicEvent{} = evt, _, %EconomicResource{} = to_res} = Domain.create(params, res_params)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value - params.resource_quantity.has_numerical_value

		assert to_res.name == res_params.name
		assert to_res.note == res_params.note
		assert to_res.image == res_params.image
		assert to_res.tracking_identifier == res_params.tracking_identifier
		assert to_res.lot_id == res_params.lot_id

		assert to_res.primary_accountable_id == params.receiver_id
		assert to_res.custodian_id == params.receiver_id
		assert to_res.accounting_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert to_res.accounting_quantity_has_unit_id == params.resource_quantity.has_unit_id
		assert to_res.onhand_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
		assert to_res.onhand_quantity_has_unit_id == params.resource_quantity.has_unit_id

		from(r in EconomicResource,
			where: r.id in ^contained_ids,
			select: map(r, ~w[primary_accountable_id custodian_id contained_in_id]a))
		|> Repo.all()
		|> Enum.each(fn r ->
			assert r.primary_accountable_id == evt.receiver_id
			assert r.custodian_id == evt.receiver_id
			assert r.contained_in_id == to_res.id
		end)
	end

	@tag :want_to_resource
	test "pass with `:to_resource_inventoried_as`", %{params: params} do
		res_before = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		to_res_before = EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)

		assert {:ok, %EconomicEvent{}} = Domain.create(params, nil)
		res_after = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		to_res_after = EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)

		assert res_after.accounting_quantity_has_numerical_value ==
			res_before.accounting_quantity_has_numerical_value - params.resource_quantity.has_numerical_value
		assert res_after.onhand_quantity_has_numerical_value ==
			res_before.onhand_quantity_has_numerical_value - params.resource_quantity.has_numerical_value

		assert to_res_after.accounting_quantity_has_numerical_value ==
			to_res_before.accounting_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
		assert to_res_after.onhand_quantity_has_numerical_value ==
			to_res_before.onhand_quantity_has_numerical_value + params.resource_quantity.has_numerical_value
	end

	test "fail when provider doesn't have accountability over the resource", %{params: params} do
		EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		|> Changeset.change(primary_accountable_id: Factory.insert!(:agent).id)
		|> Repo.update!()
		assert {:error, "you don't have accountability over resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	test "fail when provider doesn't have custody over the resource", %{params: params} do
		EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		|> Changeset.change(custodian_id: Factory.insert!(:agent).id)
		|> Repo.update!()
		assert {:error, "you don't have custody over resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when provider doesn't have accountability over the to-resource", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(primary_accountable_id: Factory.insert!(:agent).id)
		|> Repo.update!()
		assert {:error, "you don't have accountability over to-resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when provider doesn't have custody over the to-resource", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(custodian_id: Factory.insert!(:agent).id)
		|> Repo.update!()
		assert {:error, "you don't have custody over to-resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_contained
	test "fail when the resource is a contained resource", %{params: params} do
		assert {:error, "you can't move a contained resource"} =
			Domain.create(params, nil)
	end

	test "fail when event's unit and resource's unit differ", %{params: params} do
		params = update_in(params.resource_quantity.has_unit_id, fn _ -> Factory.insert!(:unit).id end)
		assert {:error, "the unit of resource-quantity must match with the unit of resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when event's unit and to-resource's unit differ", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(accounting_quantity_has_unit_id: Factory.insert!(:unit).id)
		|> Repo.update!()

		assert {:error, "the unit of resource-quantity must match with the unit of to-resource-inventoried-as"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container and accounting-quantity is non-positive", %{params: params} do
		err = "the move events need container resources to have positive accounting-quantity"
		res = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		Changeset.change(res, accounting_quantity_has_numerical_value: 0.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)

		Changeset.change(res, accounting_quantity_has_numerical_value: -1.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when the resource is a container and onhand-quantity is non-positive", %{params: params} do
		err = "the move events need container resources to have positive onhand-quantity"
		res = EconomicResource.Domain.by_id(params.resource_inventoried_as_id)

		Changeset.change(res, onhand_quantity_has_numerical_value: 0.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)

		Changeset.change(res, onhand_quantity_has_numerical_value: -1.0) |> Repo.update!()
		assert {:error, ^err} = Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when event's quantity value and resource's accounting-quantity value differ", %{params: params} do
		EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		|> Changeset.change(accounting_quantity_has_numerical_value: params.resource_quantity.has_numerical_value + 1)
		|> Repo.update!()
		assert {:error, "the move events need to fully move the resource"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	test "fail when event's quantity value and resource's onhnad-quantity value differ", %{params: params} do
		EconomicResource.Domain.by_id(params.resource_inventoried_as_id)
		|> Changeset.change(onhand_quantity_has_numerical_value: params.resource_quantity.has_numerical_value + 1)
		|> Repo.update!()
		assert {:error, "the move events need to fully move the resource"} =
			Domain.create(params, nil)
	end

	@tag :want_container
	@tag :want_to_resource
	test "fail when transfering a container resource into another resource", %{params: params} do
		assert {:error, "you can't move a container resource into another resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when the to-resource is a contained resource", %{params: params} do
		agent = Factory.insert!(:agent)
		raise_params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}
		assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
		# TODO: use combine-separate when implemented instead
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(contained_in_id: tmp_res.id)
		|> Repo.update!()

		assert {:error, "you can't move into a contained resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when the to-resource is a container resource", %{params: params} do
		agent = Factory.insert!(:agent)
		raise_params = %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.float(),
			},
			has_end: DateTime.utc_now(),
		}
		assert {:ok, _, tmp_res, _} = Domain.create(raise_params, %{name: Factory.str("name")})
		# TODO: use combine-separate when implemented instead
		Changeset.change(tmp_res, contained_in_id: params.to_resource_inventoried_as_id)
		|> Repo.update()

		assert {:error, "you can't move into a container resource"} =
			Domain.create(params, nil)
	end

	@tag :want_to_resource
	test "fail when resoure and to-resource don't conform to the same spec", %{params: params} do
		EconomicResource.Domain.by_id(params.to_resource_inventoried_as_id)
		|> Changeset.change(conforms_to_id: Factory.insert!(:resource_specification).id)
		|> Repo.update!()

		assert {:error, "the resources must conform to the same specification"} =
			Domain.create(params, nil)
	end
end

describe "update/2" do
end

describe "preload/2" do
	# test "preloads :resource_quantity", %{inserted: eco_evt} do
	# 	eco_evt = Domain.preload(eco_evt, :resource_quantity)
	# 	assert res_qty = %Measure{} = eco_evt.resource_quantity
	# 	assert res_qty.has_unit_id == eco_evt.resource_quantity_has_unit_id
	# 	assert res_qty.has_numerical_value == eco_evt.resource_quantity_has_numerical_value
	# end

	# test "preloads :effort_quantity", %{inserted: eco_evt} do
	# 	eco_evt = Domain.preload(eco_evt, :effort_quantity)
	# 	assert eff_qty = %Measure{} = eco_evt.effort_quantity
	# 	assert eff_qty.has_unit_id == eco_evt.effort_quantity_has_unit_id
	# 	assert eff_qty.has_numerical_value == eco_evt.effort_quantity_has_numerical_value
	# end

	# test "preloads :inserted_resource", %{inserted: eco_evt} do
	# 	eco_evt = Domain.preload(eco_evt, :inserted_resource)
	# 	assert eco_evt_res = %RecipeResource{} = eco_evt.inserted_resource
	# 	assert eco_evt_res.id == eco_evt.inserted_resource_id
	# end

	# test "preloads :action", %{inserted: eco_evt} do
	# 	eco_evt = Domain.preload(eco_evt, :action)
	# 	assert action = %Action{} = eco_evt.action
	# 	assert action.id == eco_evt.action_id
	# end

	# test "preloads :recipe_input_of", %{inserted: eco_evt} do
	# 	eco_evt = Domain.preload(eco_evt, :recipe_input_of)
	# 	assert rec_in_of = %RecipeProcess{} = eco_evt.recipe_input_of
	# 	assert rec_in_of.id == eco_evt.recipe_input_of_id
	# end

	# test "preloads :recipe_output_of", %{inserted: eco_evt} do
	# 	eco_evt = Domain.preload(eco_evt, :recipe_output_of)
	# 	assert rec_out_of = %RecipeProcess{} = eco_evt.recipe_output_of
	# 	assert rec_out_of.id == eco_evt.recipe_output_of_id
	# end

	# test "preloads :recipe_clause_of", %{inserted: eco_evt} do
	# 	eco_evt = Domain.preload(eco_evt, :recipe_clause_of)
	# 	assert rec_clause_of = %RecipeExchange{} = eco_evt.recipe_clause_of
	# 	assert rec_clause_of.id == eco_evt.recipe_clause_of_id
	# end
end
end
