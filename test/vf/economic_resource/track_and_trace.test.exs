defmodule ZenflowsTest.VF.EconomicResource.TrackAndTrace do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.{
	EconomicEvent,
	EconomicResource,
	EconomicResource.Domain,
	Organization,
	Process,
	ProcessSpecification,
	ResourceSpecification,
	Unit,
}

test "previous/2 works" do
	agent = Factory.insert!(:agent)
	unit = Factory.insert!(:unit)
	amount = Factory.decimal()

	evt0 = EconomicEvent.Domain.create!(%{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			resource_quantity: %{
				has_numerical_value: amount,
				has_unit_id: unit.id,
			},
			has_point_in_time: Factory.now(),
		}, %{name: Factory.str("name")})
	res = Domain.one!(evt0.resource_inventoried_as_id)
	assert res.previous_event_id == evt0.id
	assert evt0.previous_event_id == nil

	evt1 = EconomicEvent.Domain.create!(%{
		action_id: "raise",
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt1.id
	assert evt1.previous_event_id == evt0.id

	evt2 = EconomicEvent.Domain.create!(%{
		action_id: "lower",
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt2.id
	assert evt2.previous_event_id == evt1.id

	evt3 = EconomicEvent.Domain.create!(%{
		action_id: "produce",
		output_of_id: Factory.insert!(:process).id,
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt3.id
	assert evt3.previous_event_id == evt2.id

	evt4 = EconomicEvent.Domain.create!(%{
		action_id: "consume",
		input_of_id: Factory.insert!(:process).id,
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: res.onhand_quantity_has_unit_id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt4.id
	assert evt4.previous_event_id == evt3.id

	evt5 = EconomicEvent.Domain.create!(%{
		action_id: "use",
		input_of_id: Factory.insert!(:process).id,
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		effort_quantity: %{
			has_numerical_value: Factory.decimal(),
			has_unit_id: Factory.insert!(:unit).id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt5.id
	assert evt5.previous_event_id == evt4.id

	evt6 = EconomicEvent.Domain.create!(%{
		action_id: "cite",
		input_of_id: Factory.insert!(:process).id,
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt6.id
	assert evt6.previous_event_id == evt5.id

	proc = Factory.insert!(:process)
	evt7 = EconomicEvent.Domain.create!(%{
		action_id: "pickup",
		input_of_id: proc.id,
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt7.id
	assert evt7.previous_event_id == evt6.id

	evt8 = EconomicEvent.Domain.create!(%{
		action_id: "dropoff",
		output_of_id: proc.id,
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt8.id
	assert evt8.previous_event_id == evt7.id

	proc = Factory.insert!(:process)
	evt9 = EconomicEvent.Domain.create!(%{
		action_id: "accept",
		input_of_id: proc.id,
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt9.id
	assert evt9.previous_event_id == evt8.id

	evt10 = EconomicEvent.Domain.create!(%{
		action_id: "modify",
		output_of_id: proc.id,
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt10.id
	assert evt10.previous_event_id == evt9.id

	evt11 = EconomicEvent.Domain.create!(%{
		action_id: "transferCustody",
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt11.id
	assert evt11.previous_event_id == evt10.id

	evt12 = EconomicEvent.Domain.create!(%{
		action_id: "transferAllRights",
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt12.id
	assert evt12.previous_event_id == evt11.id

	evt13 = EconomicEvent.Domain.create!(%{
		action_id: "transfer",
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt13.id
	assert evt13.previous_event_id == evt12.id

	evt14 = EconomicEvent.Domain.create!(%{
		action_id: "move",
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_inventoried_as_id: res.id,
		resource_quantity: %{
			has_numerical_value: amount,
			has_unit_id: unit.id,
		},
		has_point_in_time: Factory.now(),
	})
	res = Domain.one!(res.id)
	assert res.previous_event_id == evt14.id
	assert evt14.previous_event_id == evt13.id

	#evts = Domain.previous(res)
	#left = Enum.map(evts, & &1.id)
	#right = Enum.map([evt0, evt1, evt2, evt3, evt8, evt10], & &1.id)
	#assert left == right
end

#defp assert_trace(left, right) do
#	if length(left) != length(right), do: throw "lengths must be the same"
#	Enum.zip(left, right)
#	|> Enum.with_index(fn {l, r}, ind ->
#		if l.__struct__ != r.__struct__ and l.id != r.id,
#			do: flunk("""
#			At index #{ind}:
#
#			#{inspect(l, pretty: true)}
#
#			DOES NOT MATCH
#
#			#{inspect(r, pretty: true)}
#			""")
#	end)
#end

test "trace/2" do
	spec_cotton = ResourceSpecification.Domain.create!(%{name: "cotton"})
	spec_water = ResourceSpecification.Domain.create!(%{name: "water"})
	spec_gown = ResourceSpecification.Domain.create!(%{name: "medical gown"})
	spec_surgery = ResourceSpecification.Domain.create!(%{name: "action of surgery"})
	spec_transport_service = ResourceSpecification.Domain.create!(%{name: "transport service"})
	spec_sewing_machine = ResourceSpecification.Domain.create!(%{name: "sewing machine"})
	spec_shirt = ResourceSpecification.Domain.create!(%{name: "shirt"})
	spec_shirt_design = ResourceSpecification.Domain.create!(%{name: "shirt design"})
	spec_shirt_design_work = ResourceSpecification.Domain.create!(%{name: "shirt design work"})

	proc_spec_clean = ProcessSpecification.Domain.create!(%{name: "gown after cleaned"})
	proc_spec_surgery = ProcessSpecification.Domain.create!(%{name: "gown after used in surgery"})

	unit_one = Unit.Domain.create!(%{label: "one", symbol: "one"})
	unit_kg = Unit.Domain.create!(%{label: "kilogram", symbol: "kg"})
	unit_lt = Unit.Domain.create!(%{label: "liter", symbol: "l"})
	unit_hour = Unit.Domain.create!(%{label: "hour", symbol: "h"})

	agent_alice = Organization.Domain.create!(%{name: "alice"})
	agent_bob = Organization.Domain.create!(%{name: "bob"})
	agent_carol = Organization.Domain.create!(%{name: "carol"})

	evt_raise = EconomicEvent.Domain.create!(%{
		action_id: "raise",
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_conforms_to_id: spec_water.id,
		resource_quantity: %{
			has_numerical_value: "100",
			has_unit_id: unit_lt.id,
		},
		has_point_in_time: DateTime.utc_now(),
	}, %{name: "water"})
	res_water = EconomicResource.Domain.one!(evt_raise.resource_inventoried_as_id)

	evt_raise = EconomicEvent.Domain.create!(%{
		action_id: "raise",
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_conforms_to_id: spec_cotton.id,
		resource_quantity: %{
			has_numerical_value: "100",
			has_unit_id: unit_kg.id,
		},
		has_point_in_time: DateTime.utc_now(),
	}, %{name: "cotton"})
	res_cotton = EconomicResource.Domain.one!(evt_raise.resource_inventoried_as_id)

	proc = Process.Domain.create!(%{name: "create gowns"})
	_evt_consume = EconomicEvent.Domain.create!(%{
		action_id: "consume",
		input_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_cotton.id,
		resource_quantity: %{
			has_numerical_value: "25",
			has_unit_id: unit_kg.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	evt_produce = EconomicEvent.Domain.create!(%{
		action_id: "produce",
		output_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_conforms_to_id: spec_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	}, %{name: "gown"})
	res_gown = EconomicResource.Domain.one!(evt_produce.resource_inventoried_as_id)

	proc = Process.Domain.create!(%{
		name: "cleaning the gowns",
		based_on_id: proc_spec_clean.id,
	})
	_evt_accept = EconomicEvent.Domain.create!(%{
		action_id: "accept",
		input_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_modify = EconomicEvent.Domain.create!(%{
		action_id: "modify",
		output_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_consume = EconomicEvent.Domain.create!(%{
		action_id: "consume",
		input_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_water.id,
		resource_quantity: %{
			has_numerical_value: "25",
			has_unit_id: unit_lt.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})

	_evt_transfer = EconomicEvent.Domain.create!(%{
		action_id: "transferCustody",
		provider_id: agent_alice.id,
		receiver_id: agent_bob.id,
		resource_inventoried_as_id: res_gown.id,
		to_resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})

	proc = Process.Domain.create!(%{
		name: "doing the surgery",
		based_on_id: proc_spec_surgery.id,
	})
	_evt_accept = EconomicEvent.Domain.create!(%{
		action_id: "accept",
		input_of_id: proc.id,
		provider_id: agent_bob.id,
		receiver_id: agent_bob.id,
		resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_modify = EconomicEvent.Domain.create!(%{
		action_id: "modify",
		output_of_id: proc.id,
		provider_id: agent_bob.id,
		receiver_id: agent_bob.id,
		resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_work = EconomicEvent.Domain.create!(%{
		action_id: "work",
		input_of_id: proc.id,
		provider_id: agent_bob.id,
		receiver_id: agent_bob.id,
		resource_conforms_to_id: spec_surgery.id,
		effort_quantity: %{
			has_numerical_value: "5",
			has_unit_id: unit_hour.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})

	_evt_transfer = EconomicEvent.Domain.create!(%{
		action_id: "transferCustody",
		provider_id: agent_bob.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_gown.id,
		to_resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})

	proc = Process.Domain.create!(%{
		name: "cleaning the gowns again",
		based_on_id: proc_spec_clean.id,
	})
	_evt_accept = EconomicEvent.Domain.create!(%{
		action_id: "accept",
		input_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_modify = EconomicEvent.Domain.create!(%{
		action_id: "modify",
		output_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_consume = EconomicEvent.Domain.create!(%{
		action_id: "consume",
		input_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_water.id,
		resource_quantity: %{
			has_numerical_value: "25",
			has_unit_id: unit_lt.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})

	evt_raise = EconomicEvent.Domain.create!(%{
		action_id: "raise",
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_conforms_to_id: spec_sewing_machine.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	}, %{name: "sewing machine"})
	res_sewing_machine = EconomicResource.Domain.one!(evt_raise.resource_inventoried_as_id)

	evt_transfer = EconomicEvent.Domain.create!(%{
		action_id: "transfer",
		provider_id: agent_alice.id,
		receiver_id: agent_carol.id,
		resource_inventoried_as_id: res_cotton.id,
		resource_quantity: %{
			has_numerical_value: "10",
			has_unit_id: unit_kg.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	res_transferred_cotton = EconomicResource.Domain.one!(evt_transfer.to_resource_inventoried_as_id)

	proc = Process.Domain.create!(%{name: "create shirt design"})
	_evt_work = EconomicEvent.Domain.create!(%{
		action_id: "work",
		input_of_id: proc.id,
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_conforms_to_id: spec_shirt_design_work.id,
		effort_quantity: %{
			has_numerical_value: "4",
			has_unit_id: unit_hour.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	evt_produce = EconomicEvent.Domain.create!(%{
		action_id: "produce",
		output_of_id: proc.id,
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_conforms_to_id: spec_shirt_design.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	}, %{name: "shirt design"})
	res_shirt_design = EconomicResource.Domain.one!(evt_produce.resource_inventoried_as_id)

	proc = Process.Domain.create!(%{name: "create shirt"})
	_evt_consume = EconomicEvent.Domain.create!(%{
		action_id: "consume",
		input_of_id: proc.id,
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_inventoried_as_id: res_transferred_cotton.id,
		resource_quantity: %{
			has_numerical_value: "5",
			has_unit_id: unit_kg.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_cite = EconomicEvent.Domain.create!(%{
		action_id: "cite",
		input_of_id: proc.id,
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_inventoried_as_id: res_shirt_design.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_use = EconomicEvent.Domain.create!(%{
		action_id: "use",
		input_of_id: proc.id,
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_inventoried_as_id: res_sewing_machine.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		effort_quantity: %{
			has_numerical_value: "3",
			has_unit_id: unit_hour.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	evt_produce = EconomicEvent.Domain.create!(%{
		action_id: "produce",
		output_of_id: proc.id,
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_conforms_to_id: spec_shirt.id,
		resource_quantity: %{
			has_numerical_value: "2",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	}, %{name: "shirt"})
	res_shirt = EconomicResource.Domain.one!(evt_produce.resource_inventoried_as_id)

	_evt_lower = EconomicEvent.Domain.create!(%{
		action_id: "lower",
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_inventoried_as_id: res_transferred_cotton.id,
		resource_quantity: %{
			has_numerical_value: "2",
			has_unit_id: unit_kg.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})

	evt_move = EconomicEvent.Domain.create!(%{
		action_id: "move",
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_inventoried_as_id: res_shirt.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	res_moved_shirt = EconomicResource.Domain.one!(evt_move.to_resource_inventoried_as_id)

	proc = Process.Domain.create!(%{name: "transport shirt"})
	_evt_pickup = EconomicEvent.Domain.create!(%{
		action_id: "pickup",
		input_of_id: proc.id,
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_inventoried_as_id: res_moved_shirt.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	evt_dropoff = EconomicEvent.Domain.create!(%{
		action_id: "dropoff",
		output_of_id: proc.id,
		provider_id: agent_carol.id,
		receiver_id: agent_carol.id,
		resource_inventoried_as_id: res_moved_shirt.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_deliver_service = EconomicEvent.Domain.create!(%{
		action_id: "deliverService",
		output_of_id: proc.id,
		provider_id: agent_carol.id,
		receiver_id: agent_alice.id,
		resource_conforms_to_id: spec_transport_service.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	evt_transfer = EconomicEvent.Domain.create!(%{
		action_id: "transfer",
		provider_id: agent_carol.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_moved_shirt.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		triggered_by_id: evt_dropoff.id,
		has_point_in_time: DateTime.utc_now(),
	})
	res_transferred_shirt = EconomicResource.Domain.one!(evt_transfer.to_resource_inventoried_as_id)

	proc = Process.Domain.create!(%{name: "clean gown and shirt", based_on_id: proc_spec_clean.id})
	_evt_accept_gown = EconomicEvent.Domain.create!(%{
		action_id: "accept",
		input_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_accept_shirt = EconomicEvent.Domain.create!(%{
		action_id: "accept",
		input_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_transferred_shirt.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_modify_gown = EconomicEvent.Domain.create!(%{
		action_id: "modify",
		output_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_gown.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
	_evt_modify_shirt = EconomicEvent.Domain.create!(%{
		action_id: "modify",
		output_of_id: proc.id,
		provider_id: agent_alice.id,
		receiver_id: agent_alice.id,
		resource_inventoried_as_id: res_transferred_shirt.id,
		resource_quantity: %{
			has_numerical_value: "1",
			has_unit_id: unit_one.id,
		},
		has_point_in_time: DateTime.utc_now(),
	})
end
end
