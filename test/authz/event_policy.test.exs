defmodule ZenflowsTest.Authz.EventPolicy do
use ExUnit.Case, async: true

alias Zenflows.Authz.{EventFacts, EventPolicy, ResourceControl}
alias Zenflows.DB.ID

setup do
	%{alice: ID.gen(), bob: ID.gen(), org: ID.gen(), losh: ID.gen(), r1: ID.gen(), r2: ID.gen(), c1: ID.gen()}
end

defp facts(c, attrs) do
	base = %EventFacts{
		provider_id: c.alice, receiver_id: c.alice, source_id: c.r1,
		controls: %{c.r1 => %ResourceControl{resource_id: c.r1, controller_id: c.alice}},
	}
	f = struct(base, attrs)
	%{f | touched: EventPolicy.touched(%{
		action_id: f.action,
		resource_inventoried_as_id: f.source_id,
		to_resource_inventoried_as_id: Keyword.get(attrs, :to_id),
		resource_conforms_to_id: Keyword.get(attrs, :conforms_to),
	})}
end

test "every ValueFlows action is in the table" do
	assert Map.keys(Zenflows.VF.Action.map()) -- EventPolicy.actions() == []
end

test "touched/1 per kind", c do
	assert %{changes: [], references: [], creates: :resource} =
		EventPolicy.touched(%{action_id: "raise", resource_conforms_to_id: ID.gen()})
	assert %{changes: [r1], creates: :none} =
		EventPolicy.touched(%{action_id: "raise", resource_inventoried_as_id: c.r1})
	assert r1 == c.r1
	assert %{changes: [_], creates: :none} =
		EventPolicy.touched(%{action_id: "consume", resource_inventoried_as_id: c.r1})
	assert %{changes: [_], creates: :destination} =
		EventPolicy.touched(%{action_id: "transfer", resource_inventoried_as_id: c.r1})
	assert %{changes: [_, _], creates: :none} =
		EventPolicy.touched(%{action_id: "transfer", resource_inventoried_as_id: c.r1, to_resource_inventoried_as_id: c.r2})
	assert %{changes: [], references: [_]} =
		EventPolicy.touched(%{action_id: "cite", resource_inventoried_as_id: c.r1})
	assert %{changes: [], references: []} = EventPolicy.touched(%{action_id: "work"})
end

describe "agent rule" do
	test "signer must act for provider or receiver", c do
		f = facts(c, action: "work", source_id: nil, controls: %{})
		assert :ok = EventPolicy.decide(c.alice, "event.create", f)
		assert {:error, :forbidden, :agent} = EventPolicy.decide(c.bob, "event.create", f)
		assert :ok = EventPolicy.decide(c.bob, "event.create", %{f | receiver_id: c.bob})
		assert :ok = EventPolicy.decide(c.bob, "event.create",
			%{f | provider_id: c.org, receiver_id: c.org, admin_of: MapSet.new([c.org])})
	end

	test "combine/separate are unsupported", c do
		assert {:error, :forbidden, :unsupported} =
			EventPolicy.decide(c.alice, "event.create", facts(c, action: "combine", source_id: nil))
	end
end

describe "resource rule" do
	test "changed resource must be controlled by the signer", c do
		f = facts(c, action: "consume", provider_id: c.bob, receiver_id: c.bob)
		assert {:error, :forbidden, :resource} = EventPolicy.decide(c.bob, "event.create", f)
		assert :ok = EventPolicy.decide(c.alice, "event.create", %{f | provider_id: c.alice, receiver_id: c.alice})
	end

	test "receiver-signed pull of someone else's resource is denied", c do
		f = facts(c, action: "transfer", provider_id: c.alice, receiver_id: c.bob)
		assert {:error, :forbidden, :resource} = EventPolicy.decide(c.bob, "event.create", f)
	end

	test "admin of the controlling org may change it", c do
		f = facts(c, action: "consume", provider_id: c.org, receiver_id: c.org,
			controls: %{c.r1 => %ResourceControl{resource_id: c.r1, controller_id: c.org}})
		assert :ok = EventPolicy.decide(c.bob, "event.create", %{f | admin_of: MapSet.new([c.org])})
		assert {:error, :forbidden, :agent} = EventPolicy.decide(c.bob, "event.create", f)
	end

	test "no control row is deny-all", c do
		assert {:error, :forbidden, :resource} =
			EventPolicy.decide(c.alice, "event.create", facts(c, action: "consume", controls: %{}))
	end

	test "existing destination must be controlled too", c do
		f = facts(c, action: "transfer", to_id: c.r2,
			controls: %{
				c.r1 => %ResourceControl{resource_id: c.r1, controller_id: c.alice},
				c.r2 => %ResourceControl{resource_id: c.r2, controller_id: c.bob},
			})
		assert {:error, :forbidden, :resource} = EventPolicy.decide(c.alice, "event.create", f)
	end

	test "container contents controlled by someone else block the change", c do
		f = facts(c, action: "transfer", receiver_id: c.bob,
			contained: %{c.r1 => [c.c1]},
			controls: %{
				c.r1 => %ResourceControl{resource_id: c.r1, controller_id: c.alice},
				c.c1 => %ResourceControl{resource_id: c.c1, controller_id: c.bob},
			})
		assert {:error, :forbidden, :resource} = EventPolicy.decide(c.alice, "event.create", f)
	end

	test "cite/use reference other agents' resources freely", c do
		f = facts(c, action: "cite", provider_id: c.bob, receiver_id: c.bob)
		assert :ok = EventPolicy.decide(c.bob, "event.create", f)
	end
end

describe "claim rule" do
	setup c do
		%{claim: facts(c, action: "transfer", provider_id: c.losh, receiver_id: c.bob,
			claimable: MapSet.new([c.losh]),
			controls: %{c.r1 => %ResourceControl{resource_id: c.r1, controller_id: c.losh}})}
	end

	test "anyone may claim to themselves into a new resource", c do
		assert :ok = EventPolicy.decide(c.bob, "event.create", c.claim)
		assert EventPolicy.claim?(c.bob, c.claim)
	end

	test "transferAllRights and transferCustody claims work; move does not", c do
		assert :ok = EventPolicy.decide(c.bob, "event.create", %{c.claim | action: "transferAllRights"})
		assert :ok = EventPolicy.decide(c.bob, "event.create", %{c.claim | action: "transferCustody"})
		assert {:error, :forbidden, :claim} = EventPolicy.decide(c.bob, "event.create", %{c.claim | action: "move"})
	end

	test "claim into an existing resource is denied", c do
		f = %{c.claim | touched: %{changes: [c.r1, c.r2], references: [], creates: :none},
			controls: Map.put(c.claim.controls, c.r2, %ResourceControl{resource_id: c.r2, controller_id: c.bob})}
		assert {:error, :forbidden, :claim} = EventPolicy.decide(c.bob, "event.create", f)
	end

	test "claim for someone else is denied", c do
		assert {:error, :forbidden, _} =
			EventPolicy.decide(c.bob, "event.create", %{c.claim | receiver_id: c.alice})
	end

	test "unlisted agent is not claimable", c do
		assert {:error, :forbidden, :resource} =
			EventPolicy.decide(c.bob, "event.create", %{c.claim | claimable: MapSet.new()})
	end

	test "container sources cannot be claimed", c do
		assert {:error, :forbidden, :claim} =
			EventPolicy.decide(c.bob, "event.create", %{c.claim | contained: %{c.r1 => [c.c1]}})
	end

	test "a controller's own transfer is not a claim", c do
		f = %{c.claim | claimable: MapSet.new([c.alice]),
			controls: %{c.r1 => %ResourceControl{resource_id: c.r1, controller_id: c.alice}},
			provider_id: c.alice}
		refute EventPolicy.claim?(c.alice, f)
	end
end

describe "event.update" do
	test "provider or receiver of the stored event", c do
		evt = %Zenflows.VF.EconomicEvent{id: ID.gen(), provider_id: c.alice, receiver_id: c.org}
		f = %EventFacts{event: evt}
		assert :ok = EventPolicy.decide(c.alice, "event.update", f)
		assert {:error, :forbidden, :agent} = EventPolicy.decide(c.bob, "event.update", f)
		assert :ok = EventPolicy.decide(c.bob, "event.update", %{f | admin_of: MapSet.new([c.org])})
		assert {:error, :forbidden, :agent} = EventPolicy.decide(c.alice, "event.update", %EventFacts{})
	end
end
end
