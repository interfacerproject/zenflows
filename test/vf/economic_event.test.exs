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

defmodule ZenflowsTest.VF.EconomicEvent do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Changeset
alias Zenflows.VF.EconomicEvent

setup_all do
	[errmsg_exist_xnor: "exactly one of them must be provided"]
end

test """
`chgset/1`: every event requires the `:action_id`, `:provider_id`,
`:receiver_id` fields and the allowed combinations of the datetime
fields `:has_point_in_time`, `:has_beginning`, `:has_end`
""" do
	assert %Changeset{valid?: false} = cset = EconomicEvent.changeset(%{})
	err = Changeset.traverse_errors(cset, &elem(&1, 0))
	assert {[_], err} = pop_in(err[:action_id])
	assert {[_], err} = pop_in(err[:provider_id])
	assert {[_], err} = pop_in(err[:receiver_id])
	assert {[_], err} = pop_in(err[:has_point_in_time])
	assert {[_], err} = pop_in(err[:has_beginning])
	assert {[_], err} = pop_in(err[:has_end])
	assert err == %{}

	assert %Changeset{valid?: false} = cset =
		EconomicEvent.changeset(%{has_point_in_time: DateTime.utc_now()})
	err = Changeset.traverse_errors(cset, &elem(&1, 0))
	assert {[_], err} = pop_in(err[:action_id])
	assert {[_], err} = pop_in(err[:provider_id])
	assert {[_], err} = pop_in(err[:receiver_id])
	assert err == %{}

	assert %Changeset{valid?: false} = cset =
		EconomicEvent.changeset(%{has_beginning: DateTime.utc_now()})
	err = Changeset.traverse_errors(cset, &elem(&1, 0))
	assert {[_], err} = pop_in(err[:action_id])
	assert {[_], err} = pop_in(err[:provider_id])
	assert {[_], err} = pop_in(err[:receiver_id])
	assert err == %{}

	assert %Changeset{valid?: false} = cset =
		EconomicEvent.changeset(%{has_end: DateTime.utc_now()})
	err = Changeset.traverse_errors(cset, &elem(&1, 0))
	assert {[_], err} = pop_in(err[:action_id])
	assert {[_], err} = pop_in(err[:provider_id])
	assert {[_], err} = pop_in(err[:receiver_id])
	assert err == %{}

	assert %Changeset{valid?: false} = cset =
		EconomicEvent.changeset(%{
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
		})
	err = Changeset.traverse_errors(cset, &elem(&1, 0))
	assert {[_], err} = pop_in(err[:action_id])
	assert {[_], err} = pop_in(err[:provider_id])
	assert {[_], err} = pop_in(err[:receiver_id])
	assert err == %{}
end

describe "`chgset/1` with raise:" do
	setup do
		agent = Factory.insert!(:agent)

		%{params: %{
			action_id: "raise",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_point_in_time: DateTime.utc_now(),
		}}
	end

	test "pass with `:resource_conforms_to`", %{params: params} do
		spec = Factory.insert!(:resource_specification)
		assert %Changeset{valid?: true} =
			params
			|> Map.put(:resource_conforms_to_id, spec.id)
			|> EconomicEvent.changeset()
	end

	test "pass with `:resource_inventoried_as`", %{params: params} do
		res = Factory.insert!(:economic_resource)
		assert %Changeset{valid?: true} =
			params
			|> Map.put(:resource_inventoried_as_id, res.id)
			|> EconomicEvent.changeset()
	end

	test "fail without `:resource_conforms_to` and `:resource_inventoried_as`",
			%{params: params, errmsg_exist_xnor: errmsg} do
		assert %Changeset{valid?: false} = cset = EconomicEvent.changeset(params)
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[^errmsg], err} = pop_in(err[:resource_conforms_to_id])
		assert {[^errmsg], err} = pop_in(err[:resource_inventoried_as_id])
		assert err == %{}
	end

	test "fail with `:resource_conforms_to` and `:resource_inventoried_as`",
			%{params: params, errmsg_exist_xnor: errmsg} do
		res = Factory.insert!(:economic_resource)
		spec = Factory.insert!(:resource_specification)
		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:resource_inventoried_as_id, res.id)
			|> Map.put(:resource_conforms_to_id, spec.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[^errmsg], err} = pop_in(err[:resource_conforms_to_id])
		assert {[^errmsg], err} = pop_in(err[:resource_inventoried_as_id])
		assert err == %{}
	end

	test "fail when `:provider` and `:receiver` differ", %{params: params} do
		params =
			Map.put(params, :resource_conforms_to_id, Factory.insert!(:resource_specification).id)
		agent = Factory.insert!(:agent)

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:provider_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:receiver_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}
	end
end

describe "`chgset/1` with produce:" do
	setup do
		agent = Factory.insert!(:agent)

		%{params: %{
			action_id: "produce",
			output_of_id: Factory.insert!(:process).id,
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_beginning: DateTime.utc_now(),
		}}
	end

	test "pass with `:resource_conforms_to`", %{params: params} do
		spec = Factory.insert!(:resource_specification)
		assert %Changeset{valid?: true} =
			params
			|> Map.put(:resource_conforms_to_id, spec.id)
			|> EconomicEvent.changeset()
	end

	test "pass with `:resource_inventoried_as`", %{params: params} do
		res = Factory.insert!(:economic_resource)
		assert %Changeset{valid?: true} =
			params
			|> Map.put(:resource_inventoried_as_id, res.id)
			|> EconomicEvent.changeset()
	end

	test "fail without `:resource_conforms_to` and `:resource_inventoried_as`",
			%{params: params, errmsg_exist_xnor: errmsg} do
		assert %Changeset{valid?: false} = cset = EconomicEvent.changeset(params)
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[^errmsg], err} = pop_in(err[:resource_conforms_to_id])
		assert {[^errmsg], err} = pop_in(err[:resource_inventoried_as_id])
		assert err == %{}
	end

	test "fail with `:resource_conforms_to` and `:resource_inventoried_as`",
		%{params: params, errmsg_exist_xnor: errmsg} do
		res = Factory.insert!(:economic_resource)
		spec = Factory.insert!(:resource_specification)
		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:resource_inventoried_as_id, res.id)
			|> Map.put(:resource_conforms_to_id, spec.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[^errmsg], err} = pop_in(err[:resource_conforms_to_id])
		assert {[^errmsg], err} = pop_in(err[:resource_inventoried_as_id])
		assert err == %{}
	end

	test "fail when `:provider` and `:receiver` differ", %{params: params} do
		params =
			Map.put(params, :resource_conforms_to_id, Factory.insert!(:resource_specification).id)
		agent = Factory.insert!(:agent)

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:provider_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:receiver_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}
	end
end

describe "`chgset/1` with lower:" do
	setup do
		agent = Factory.insert!(:agent)

		%{params: %{
			action_id: "lower",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_end: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		assert %Changeset{valid?: true} = EconomicEvent.changeset(params)
	end

	test "fail when `:provider` and `:receiver` differ", %{params: params} do
		agent = Factory.insert!(:agent)

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:provider_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:receiver_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}
	end
end

describe "`chgset/1` with consume:" do
	setup do
		agent = Factory.insert!(:agent)

		%{params: %{
			action_id: "consume",
			input_of_id: Factory.insert!(:process).id,
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		assert %Changeset{valid?: true} = EconomicEvent.changeset(params)
	end

	test "fail when `:provider` and `:receiver` differ", %{params: params} do
		agent = Factory.insert!(:agent)

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:provider_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:receiver_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}
	end
end

describe "`chgset/1` with use:" do
	setup do
		%{params: %{
			action_id: "use",
			input_of_id: Factory.insert!(:process).id,
			provider_id: Factory.insert!(:agent).id,
			receiver_id: Factory.insert!(:agent).id,
			effort_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_point_in_time: DateTime.utc_now(),
		}}
	end

	test "fail without `:resource_conforms_to` and `:resource_inventoried_as`",
		%{params: params, errmsg_exist_xnor: errmsg} do
		assert %Changeset{valid?: false} = cset = EconomicEvent.changeset(params)
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[^errmsg], err} = pop_in(err[:resource_conforms_to_id])
		assert {[^errmsg], err} = pop_in(err[:resource_inventoried_as_id])
		assert err == %{}
	end

	test "fail with `:resource_conforms_to` and `:resource_inventoried_as`",
			%{params: params, errmsg_exist_xnor: errmsg} do
		res = Factory.insert!(:economic_resource)
		spec = Factory.insert!(:resource_specification)
		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:resource_inventoried_as_id, res.id)
			|> Map.put(:resource_conforms_to_id, spec.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[^errmsg], err} = pop_in(err[:resource_conforms_to_id])
		assert {[^errmsg], err} = pop_in(err[:resource_inventoried_as_id])
		assert err == %{}
	end

	test "pass with `:resource_conforms_to`", %{params: params} do
		spec = Factory.insert!(:resource_specification)
		assert %Changeset{valid?: true} =
			params
			|> Map.put(:resource_conforms_to_id, spec.id)
			|> EconomicEvent.changeset()
	end

	test "pass with `:resource_inventoried_as`", %{params: params} do
		res = Factory.insert!(:economic_resource)
		assert %Changeset{valid?: true} =
			params
			|> Map.put(:resource_inventoried_as_id, res.id)
			|> EconomicEvent.changeset()
	end
end

test "`chgset/1` with work: pass when all good" do
	assert %Changeset{valid?: true} = EconomicEvent.changeset(%{
		action_id: "work",
		input_of_id: Factory.insert!(:process).id,
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		resource_conforms_to_id: Factory.insert!(:resource_specification).id,
		effort_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.decimal(),
		},
		has_beginning: DateTime.utc_now(),
	})
end

describe "`chgset/1` with cite:" do
	setup do
		%{params: %{
			action_id: "cite",
			input_of_id: Factory.insert!(:process).id,
			provider_id: Factory.insert!(:agent).id,
			receiver_id: Factory.insert!(:agent).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_end: DateTime.utc_now(),
		}}
	end

	test "pass with `:resource_conforms_to`", %{params: params} do
		spec = Factory.insert!(:resource_specification)
		assert %Changeset{valid?: true} =
			params
			|> Map.put(:resource_conforms_to_id, spec.id)
			|> EconomicEvent.changeset()
	end

	test "pass with `:resource_inventoried_as`", %{params: params} do
		res = Factory.insert!(:economic_resource)
		assert %Changeset{valid?: true} =
			params
			|> Map.put(:resource_inventoried_as_id, res.id)
			|> EconomicEvent.changeset()
	end

	test "fail without `:resource_conforms_to` and `:resource_inventoried_as`",
			%{params: params, errmsg_exist_xnor: errmsg} do
		assert %Changeset{valid?: false} = cset = EconomicEvent.changeset(params)
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[^errmsg], err} = pop_in(err[:resource_conforms_to_id])
		assert {[^errmsg], err} = pop_in(err[:resource_inventoried_as_id])
		assert err == %{}
	end

	test "fail with `:resource_conforms_to` and `:resource_inventoried_as`",
			%{params: params, errmsg_exist_xnor: errmsg} do
		res = Factory.insert!(:economic_resource)
		spec = Factory.insert!(:resource_specification)
		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:resource_inventoried_as_id, res.id)
			|> Map.put(:resource_conforms_to_id, spec.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[^errmsg], err} = pop_in(err[:resource_conforms_to_id])
		assert {[^errmsg], err} = pop_in(err[:resource_inventoried_as_id])
		assert err == %{}
	end
end

describe "`chgset/1` with deliverService:" do
	setup do
		%{params: %{
			action_id: "deliverService",
			input_of_id: Factory.insert!(:process).id,
			output_of_id: Factory.insert!(:process).id,
			provider_id: Factory.insert!(:agent).id,
			receiver_id: Factory.insert!(:agent).id,
			resource_conforms_to_id: Factory.insert!(:resource_specification).id,
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
		}}
	end

	test "fail with `:input_of` and `:output_of` same", %{params: params} do
		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:output_of_id, params.input_of_id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		msg = "all of them must be different"
		assert {[^msg], err} = pop_in(err[:input_of_id])
		assert {[^msg], err} = pop_in(err[:output_of_id])
		assert err == %{}
	end

	test "pass with `:input_of` and `:output_of` differ", %{params: params} do
		assert %Changeset{valid?: true} = EconomicEvent.changeset(params)
	end

	test "pass without `:input_of`", %{params: params} do
		assert %Changeset{valid?: true} =
			params
			|> Map.delete(:input_of)
			|> EconomicEvent.changeset()
	end

	test "pass without `:output_of`", %{params: params} do
		assert %Changeset{valid?: true} =
			params
			|> Map.delete(:output_of)
			|> EconomicEvent.changeset()
	end
end

describe "`chgset/1` with pickup:" do
	setup do
		agent = Factory.insert!(:agent)

		%{params: %{
			action_id: "pickup",
			input_of_id: Factory.insert!(:process).id,
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_point_in_time: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		assert %Changeset{valid?: true} = EconomicEvent.changeset(params)
	end

	test "fail when `:provider` and `:receiver` differ", %{params: params} do
		agent = Factory.insert!(:agent)

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:provider_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:receiver_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}
	end
end

describe "`chgset/1` with dropoff:" do
	setup do
		agent = Factory.insert!(:agent)

		%{params: %{
			action_id: "dropoff",
			output_of_id: Factory.insert!(:process).id,
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			to_location_id: Factory.insert!(:spatial_thing).id,
			has_beginning: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		assert %Changeset{valid?: true} = EconomicEvent.changeset(params)
	end

	test "fail when `:provider` and `:receiver` differ", %{params: params} do
		agent = Factory.insert!(:agent)

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:provider_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:receiver_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}
	end
end

describe "`chgset/1` with accept:" do
	setup do
		agent = Factory.insert!(:agent)

		%{params: %{
			action_id: "pickup",
			input_of_id: Factory.insert!(:process).id,
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_end: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		assert %Changeset{valid?: true} = EconomicEvent.changeset(params)
	end

	test "fail when `:provider` and `:receiver` differ", %{params: params} do
		agent = Factory.insert!(:agent)

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:provider_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:receiver_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}
	end
end

describe "`chgset/1` with modify:" do
	setup do
		agent = Factory.insert!(:agent)

		%{params: %{
			action_id: "modify",
			output_of_id: Factory.insert!(:process).id,
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_beginning: DateTime.utc_now(),
			has_end: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		assert %Changeset{valid?: true} = EconomicEvent.changeset(params)
	end

	test "fail when `:provider` and `:receiver` differ", %{params: params} do
		agent = Factory.insert!(:agent)

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:provider_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:receiver_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}
	end
end

test "`chgset/1` with transferCustody: pass when all good" do
	assert %Changeset{valid?: true} = EconomicEvent.changeset(%{
		action_id: "transferCustody",
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
		resource_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.decimal(),
		},
		has_beginning: DateTime.utc_now(),
	})
end

test "`chgset/1` with transferAllRights: pass when all good" do
	assert %Changeset{valid?: true} = EconomicEvent.changeset(%{
		action_id: "transferAllRights",
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
		resource_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.decimal(),
		},
		to_location_id: Factory.insert!(:spatial_thing).id,
		has_end: DateTime.utc_now(),
	})
end

test "`chgset/1` with transfer: pass when all good" do
	assert %Changeset{valid?: true} = EconomicEvent.changeset(%{
		action_id: "transfer",
		provider_id: Factory.insert!(:agent).id,
		receiver_id: Factory.insert!(:agent).id,
		resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
		resource_quantity: %{
			has_unit_id: Factory.insert!(:unit).id,
			has_numerical_value: Factory.decimal(),
		},
		to_location_id: Factory.insert!(:spatial_thing).id,
		has_beginning: DateTime.utc_now(),
		has_end: DateTime.utc_now(),
	})
end

describe "`chgset/1` with move:" do
	setup do
		agent = Factory.insert!(:agent)
		%{params: %{
			action_id: "move",
			provider_id: agent.id,
			receiver_id: agent.id,
			resource_inventoried_as_id: Factory.insert!(:economic_resource).id,
			resource_quantity: %{
				has_unit_id: Factory.insert!(:unit).id,
				has_numerical_value: Factory.decimal(),
			},
			has_point_in_time: DateTime.utc_now(),
		}}
	end

	test "pass when all good", %{params: params} do
		assert %Changeset{valid?: true} = EconomicEvent.changeset(params)
	end

	test "fail when `:provider` and `:receiver` differ", %{params: params} do
		agent = Factory.insert!(:agent)

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:provider_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}

		assert %Changeset{valid?: false} = cset =
			params
			|> Map.put(:receiver_id, agent.id)
			|> EconomicEvent.changeset()
		err = Changeset.traverse_errors(cset, &elem(&1, 0))
		assert {[_], err} = pop_in(err[:provider_id])
		assert {[_], err} = pop_in(err[:receiver_id])
		assert err == %{}
	end
end

describe "" do
	# @tag skip: "TODO: fix events in factory"
	# test "with both :resource_conforms_to and :resource_inventoried_as", %{params: params} do
	# 	params = params
	# 		|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
	# 		|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
	# 		|> Map.put(:has_point_in_time, DateTime.utc_now())

	# 	assert {:error, %Changeset{errors: errs}} =
	# 		params
	# 		|> EconomicEvent.changeset()
	# 		|> Repo.insert()

	# 	assert {:ok, _} = Keyword.fetch(errs, :resource_conforms_to_id)
	# 	assert {:ok, _} = Keyword.fetch(errs, :resource_inventoried_as_id)
	# end

	# @tag skip: "TODO: fix events in factory"
	# test "with both :resource_conforms_to and :to_resource_inventoried_as", %{params: params} do
	# 	params = params
	# 		|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
	# 		|> Map.put(:to_resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
	# 		|> Map.put(:has_point_in_time, DateTime.utc_now())

	# 	assert {:error, %Changeset{errors: errs}} =
	# 		params
	# 		|> EconomicEvent.changeset()
	# 		|> Repo.insert()

	# 	assert {:ok, _} = Keyword.fetch(errs, :resource_conforms_to_id)
	# 	assert {:ok, _} = Keyword.fetch(errs, :to_resource_inventoried_as_id)
	# end

	# @tag skip: "TODO: fix events in factory"
	# test "with only :resource_inventoried_as", %{params: params} do
	# 	params = params
	# 		|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
	# 		|> Map.put(:has_point_in_time, DateTime.utc_now())

	# 	assert {:ok, %EconomicEvent{} = eco_evt} =
	# 		params
	# 		|> EconomicEvent.changeset()
	# 		|> Repo.insert()

	# 	assert eco_evt.action_id == params.action_id
	# 	assert eco_evt.provider_id == params.provider_id
	# 	assert eco_evt.receiver_id == params.receiver_id
	# 	assert eco_evt.input_of_id == params.input_of_id
	# 	assert eco_evt.output_of_id == params.output_of_id
	# 	assert eco_evt.resource_inventoried_as_id == params.resource_inventoried_as_id
	# 	assert eco_evt.to_resource_inventoried_as_id == nil
	# 	assert eco_evt.resource_classified_as == params.resource_classified_as
	# 	assert eco_evt.resource_conforms_to_id == nil
	# 	assert eco_evt.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	# 	assert eco_evt.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	# 	assert eco_evt.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	# 	assert eco_evt.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	# 	assert eco_evt.realization_of_id == params.realization_of_id
	# 	assert eco_evt.at_location_id == params.at_location_id
	# 	assert eco_evt.has_beginning == nil
	# 	assert eco_evt.has_end == nil
	# 	assert eco_evt.has_point_in_time == params.has_point_in_time
	# 	assert eco_evt.note == params.note
	# 	# assert in_scope_of
	# 	assert eco_evt.agreed_in == params.agreed_in
	# 	assert eco_evt.triggered_by_id == params.triggered_by_id
	# end

	# @tag skip: "TODO: fix events in factory"
	# test "with only :to_resource_inventoried_as", %{params: params} do
	# 	params = params
	# 		|> Map.put(:to_resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
	# 		|> Map.put(:has_point_in_time, DateTime.utc_now())

	# 	assert {:ok, %EconomicEvent{} = eco_evt} =
	# 		params
	# 		|> EconomicEvent.changeset()
	# 		|> Repo.insert()

	# 	assert eco_evt.action_id == params.action_id
	# 	assert eco_evt.provider_id == params.provider_id
	# 	assert eco_evt.receiver_id == params.receiver_id
	# 	assert eco_evt.input_of_id == params.input_of_id
	# 	assert eco_evt.output_of_id == params.output_of_id
	# 	assert eco_evt.resource_inventoried_as_id == nil
	# 	assert eco_evt.to_resource_inventoried_as_id == params.to_resource_inventoried_as_id
	# 	assert eco_evt.resource_classified_as == params.resource_classified_as
	# 	assert eco_evt.resource_conforms_to_id == nil
	# 	assert eco_evt.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	# 	assert eco_evt.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	# 	assert eco_evt.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	# 	assert eco_evt.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	# 	assert eco_evt.realization_of_id == params.realization_of_id
	# 	assert eco_evt.at_location_id == params.at_location_id
	# 	assert eco_evt.has_beginning == nil
	# 	assert eco_evt.has_end == nil
	# 	assert eco_evt.has_point_in_time == params.has_point_in_time
	# 	assert eco_evt.note == params.note
	# 	# assert in_scope_of
	# 	assert eco_evt.agreed_in == params.agreed_in
	# 	assert eco_evt.triggered_by_id == params.triggered_by_id
	# end

	# @tag skip: "TODO: fix events in factory"
	# test "with both :resource_inventoried_as and :to_resource_inventoried_as", %{params: params} do
	# 	params = params
	# 		|> Map.put(:resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
	# 		|> Map.put(:to_resource_inventoried_as_id, Factory.insert!(:economic_resource).id)
	# 		|> Map.put(:has_point_in_time, DateTime.utc_now())

	# 	assert {:ok, %EconomicEvent{} = eco_evt} =
	# 		params
	# 		|> EconomicEvent.changeset()
	# 		|> Repo.insert()

	# 	assert eco_evt.action_id == params.action_id
	# 	assert eco_evt.provider_id == params.provider_id
	# 	assert eco_evt.receiver_id == params.receiver_id
	# 	assert eco_evt.input_of_id == params.input_of_id
	# 	assert eco_evt.output_of_id == params.output_of_id
	# 	assert eco_evt.resource_inventoried_as_id == params.resource_inventoried_as_id
	# 	assert eco_evt.to_resource_inventoried_as_id == params.to_resource_inventoried_as_id
	# 	assert eco_evt.resource_classified_as == params.resource_classified_as
	# 	assert eco_evt.resource_conforms_to_id == nil
	# 	assert eco_evt.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	# 	assert eco_evt.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	# 	assert eco_evt.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	# 	assert eco_evt.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	# 	assert eco_evt.realization_of_id == params.realization_of_id
	# 	assert eco_evt.at_location_id == params.at_location_id
	# 	assert eco_evt.has_beginning == nil
	# 	assert eco_evt.has_end == nil
	# 	assert eco_evt.has_point_in_time == params.has_point_in_time
	# 	assert eco_evt.note == params.note
	# 	# assert in_scope_of
	# 	assert eco_evt.agreed_in == params.agreed_in
	# 	assert eco_evt.triggered_by_id == params.triggered_by_id
	# end

	# @tag skip: "TODO: fix events in factory"
	# test "with only :resource_conforms_to", %{params: params} do
	# 	params = params
	# 		|> Map.put(:resource_conforms_to_id, Factory.insert!(:resource_specification).id)
	# 		|> Map.put(:has_point_in_time, DateTime.utc_now())

	# 	assert {:ok, %EconomicEvent{} = eco_evt} =
	# 		params
	# 		|> EconomicEvent.changeset()
	# 		|> Repo.insert()

	# 	assert eco_evt.action_id == params.action_id
	# 	assert eco_evt.provider_id == params.provider_id
	# 	assert eco_evt.receiver_id == params.receiver_id
	# 	assert eco_evt.input_of_id == params.input_of_id
	# 	assert eco_evt.output_of_id == params.output_of_id
	# 	assert eco_evt.resource_inventoried_as_id == nil
	# 	assert eco_evt.to_resource_inventoried_as_id == nil
	# 	assert eco_evt.resource_classified_as == params.resource_classified_as
	# 	assert eco_evt.resource_conforms_to_id == params.resource_conforms_to_id
	# 	assert eco_evt.resource_quantity_has_unit_id == params.resource_quantity.has_unit_id
	# 	assert eco_evt.resource_quantity_has_numerical_value == params.resource_quantity.has_numerical_value
	# 	assert eco_evt.effort_quantity_has_unit_id == params.effort_quantity.has_unit_id
	# 	assert eco_evt.effort_quantity_has_numerical_value == params.effort_quantity.has_numerical_value
	# 	assert eco_evt.realization_of_id == params.realization_of_id
	# 	assert eco_evt.at_location_id == params.at_location_id
	# 	assert eco_evt.has_beginning == nil
	# 	assert eco_evt.has_end == nil
	# 	assert eco_evt.has_point_in_time == params.has_point_in_time
	# 	assert eco_evt.note == params.note
	# 	# assert in_scope_of
	# 	assert eco_evt.agreed_in == params.agreed_in
	# 	assert eco_evt.triggered_by_id == params.triggered_by_id
	# end
end

@tag skip: "TODO: fix events in factory"
test "update EconomicEvent", %{params: _params} do
	# old = Factory.insert!(:economic_event)

	# assert {:ok, %EconomicEvent{} = new} =
	# 	old
	# 	|> EconomicEvent.changeset(params)
	# 	|> Repo.update()

	# assert new.action_id == old.action_id
	# assert new.provider_id == old.provider_id
	# assert new.receiver_id == old.receiver_id
	# assert new.input_of_id == old.input_of_id
	# assert new.output_of_id == old.output_of_id
	# assert new.resource_inventoried_as_id == old.resource_inventoried_as_id
	# assert new.to_resource_inventoried_as_id == old.to_resource_inventoried_as_id
	# assert new.resource_classified_as == old.resource_classified_as
	# assert new.resource_conforms_to_id == old.resource_conforms_to_id
	# assert new.resource_quantity_has_unit_id == old.resource_quantity_has_unit_id
	# assert new.resource_quantity_has_numerical_value == old.resource_quantity_has_numerical_value
	# assert new.effort_quantity_has_unit_id == old.effort_quantity_has_unit_id
	# assert new.effort_quantity_has_numerical_value == old.effort_quantity_has_numerical_value
	# assert new.realization_of_id == params.realization_of_id
	# assert new.at_location_id == old.at_location_id
	# assert new.has_beginning == old.has_beginning
	# assert new.has_end == old.has_end
	# assert new.has_point_in_time == old.has_point_in_time
	# assert new.note == params.note
	# # assert in_scope_of
	# assert new.agreed_in == params.agreed_in
	# assert new.triggered_by_id == params.triggered_by_id
end
end
