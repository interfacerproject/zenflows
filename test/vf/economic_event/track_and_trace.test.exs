defmodule ZenflowsTest.VF.EconomicEvent.TrackAndTrace do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.VF.{
	EconomicEvent.Domain,
	EconomicResource,
	Process,
}

test "previous/2 works" do
	agent = Factory.insert!(:agent)
	unit = Factory.insert!(:unit)
	amount = 42

	evt0 = Domain.create!(%{
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
	assert Domain.previous(evt0) == nil

	evt1 = Domain.create!(%{
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
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt1)

	proc = Factory.insert!(:process)
	evt2 = Domain.create!(%{
		action_id: "produce",
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
	assert res.previous_event_id == evt2.id
	assert evt2.previous_event_id == evt1.id
	id = proc.id
	assert %Process{id: ^id} = Domain.previous(evt2)

	evt3 = Domain.create!(%{
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
	assert res.previous_event_id == evt3.id
	assert evt3.previous_event_id == evt2.id
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt3)

	evt4 = Domain.create!(%{
		action_id: "consume",
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
	res = EconomicResource.Domain.one!(res.id)
	assert res.previous_event_id == evt4.id
	assert evt4.previous_event_id == evt3.id
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt4)

	evt5 = Domain.create!(%{
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
	res = EconomicResource.Domain.one!(res.id)
	assert res.previous_event_id == evt5.id
	assert evt5.previous_event_id == evt4.id
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt5)

	evt6 = Domain.create!(%{
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
	res = EconomicResource.Domain.one!(res.id)
	assert res.previous_event_id == evt6.id
	assert evt6.previous_event_id == evt5.id
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt6)

	proc = Factory.insert!(:process)
	evt7 = Domain.create!(%{
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
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt7)

	evt8 = Domain.create!(%{
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
	id = proc.id
	assert %Process{id: ^id} = Domain.previous(evt8)

	proc = Factory.insert!(:process)
	evt9 = Domain.create!(%{
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
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt9)

	evt10 = Domain.create!(%{
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
	id = proc.id
	assert %Process{id: ^id} = Domain.previous(evt10)

	evt11 = Domain.create!(%{
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
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt11)

	evt12 = Domain.create!(%{
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
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt12)

	evt13 = Domain.create!(%{
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
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt13)

	evt14 = Domain.create!(%{
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
	id = res.id
	assert %EconomicResource{id: ^id} = Domain.previous(evt14)
end
end
