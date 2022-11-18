defmodule ZenflowsTest.VF.Process.TrackAndTrace do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.{
	EconomicEvent,
	EconomicResource,
	Process.Domain,
}

test "previous/2 works" do
	agent = Factory.insert!(:agent)
	unit = Factory.insert!(:unit)
	amount = Factory.decimal()
	proc = Factory.insert!(:process)

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
	res = EconomicResource.Domain.one!(evt0.resource_inventoried_as_id)
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
	res = EconomicResource.Domain.one!(res.id)
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
	res = EconomicResource.Domain.one!(res.id)
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
	res = EconomicResource.Domain.one!(res.id)
	assert res.previous_event_id == evt3.id
	assert evt3.previous_event_id == evt2.id

	evt4 = EconomicEvent.Domain.create!(%{
		action_id: "consume",
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
	res = EconomicResource.Domain.one!(res.id)
	assert res.previous_event_id == evt4.id
	assert evt4.previous_event_id == evt3.id

	evt5 = EconomicEvent.Domain.create!(%{
		action_id: "use",
		input_of_id: proc.id,
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
	res = EconomicResource.Domain.one!(res.id)
	assert res.previous_event_id == evt5.id
	assert evt5.previous_event_id == evt4.id

	evt6 = EconomicEvent.Domain.create!(%{
		action_id: "cite",
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
	res = EconomicResource.Domain.one!(res.id)
	assert res.previous_event_id == evt6.id
	assert evt6.previous_event_id == evt5.id

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
	res = EconomicResource.Domain.one!(res.id)
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
	res = EconomicResource.Domain.one!(res.id)
	assert res.previous_event_id == evt8.id
	assert evt8.previous_event_id == evt7.id

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
	res = EconomicResource.Domain.one!(res.id)
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
	res = EconomicResource.Domain.one!(res.id)
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
	res = EconomicResource.Domain.one!(res.id)
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
	res = EconomicResource.Domain.one!(res.id)
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
	res = EconomicResource.Domain.one!(res.id)
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
	res = EconomicResource.Domain.one!(res.id)
	assert res.previous_event_id == evt14.id
	assert evt14.previous_event_id == evt13.id

	evts = Domain.previous(proc)
	left = Enum.map(evts, & &1.id)
	right = Enum.map([evt4, evt5, evt6, evt7, evt9], & &1.id)
	assert left == right
end
end
