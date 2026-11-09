<!--
SPDX-License-Identifier: AGPL-3.0-or-later
Zenflows is software that implements the Valueflows vocabulary.
Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

# Event authorization (RBAC slice 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `createEconomicEvent` and `updateEconomicEvent` are decided by
who signs, whom they act for, and which resources the event changes —
before the event row is written, in the same transaction, with row locks.

**Architecture:** A pure `Zenflows.Authz.EventPolicy` (action table +
decision) and a loader `Zenflows.Authz.EventFacts` (locks resources,
controls and admin rows in a fixed order) plug into the existing slice-1
`Zenflows.Authz.authorize/4`. `EconomicEvent.Domain.multi_insert` gains
one authorize step before the event insert; transfer-type creations get
the receiver as controller; claims of resources held by configured
"claimable" agents are logged.

**Tech Stack:** Elixir 1.14 / OTP 25, Ecto SQL + PostgreSQL, Absinthe
1.7.1, ExUnit with SQL Sandbox (and `unboxed_run` for concurrency tests).

**Spec:** `docs/authz-events-design.md` (read it first). Slice 1 spec:
`docs/authz-foundation-design.md`.

## Spec deltas (decided while planning — fold into the spec in Task 7)

1. No boot warning for `AUTHZ_CLAIMABLE_AGENTS` ids that are not existing
   agents: validation runs in `Application.start/2` before the Repo starts.
   Only ULID syntax is checked (invalid → refuse to start).
2. `Policy.authorize/4` may return `{:error, reason, rule}`;
   `Zenflows.Authz.authorize/4` strips the rule (callers still see
   `{:error, reason}`) and puts it in deny telemetry.
3. `updateEconomicEvent` is broken today (resolver matches
   `%{economic_event: ...}`, the argument is `event`); this slice fixes the
   resolver head while wiring authorization.
4. Raising/producing in another agent's name is now denied, so the slice-1
   tests "foreign receiver: verified creator controls" and "org receiver:
   creator controls when not an admin" are replaced by FORBIDDEN tests.

## Global Constraints

- Tabs for indentation, no indentation of top-level module code, trailing
  commas in multi-line literals.
- Every new file (tests included) starts with the repo's AGPL SPDX header
  (copy lines 1-17 of `src/zenflows/authz/policy.ex`; docs use the HTML
  comment header of `docs/authz-foundation-design.md`).
- New Policy actions: exactly `"event.create"` and `"event.update"`.
- `:import` and `:migration` service action sets gain `"event.create"`.
- Config key: `config :zenflows, Zenflows.Authz, claimable_agents: [ULID]`
  from env `AUTHZ_CLAIMABLE_AGENTS` (comma-separated, default empty).
- New log action: `"resource.claim"`; new log `after` keys: `event_id`,
  `resource_id`.
- Deny telemetry metadata key `rule` ∈ `:agent | :resource | :claim |
  :unsupported | nil`.
- Lock order inside an event decision: resource rows (one query, `ORDER BY
  id`, `FOR UPDATE`) → control rows (one query, `ORDER BY resource_id`,
  `FOR UPDATE`) → admin rows (`Facts.admin_of/3`, `FOR SHARE`).
- No new compile warnings (one pre-existing `Jason.Encoder` redefinition
  warning exists).
- Test baseline: 684 tests, 7 known failures
  (`test/restroom.test.exs:25,35,41`,
  `test/vf/economic_resource/domain.test.exs:81`,
  `test/vf/person/type.test.exs:94,155`,
  `test/authz/organization.test.exs:79`). Never add failures.
- Stage files explicitly (`git add <paths>`; migrations, if any, with
  `-f`). Commit messages end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Container contents** — a transfer of a container whose contents are
   controlled by someone else must be denied even when the signer controls
   the container. Pinned in Task 4.
2. **Claim into an existing resource** — a claim must create a new
   destination; transferring a LOSH resource into an existing resource of
   the signer is denied. Pinned in Task 2 (unit) and Task 4 (domain).
3. **Invalid event params** — an invalid changeset returns the same
   changeset error as before and takes no locks (no FORBIDDEN masking a
   validation error for unchecked callers). Pinned in Task 4.
4. **Unchecked anonymous tests** — every existing event test runs with
   `Factory.ctx()` (anonymous, `allow_unchecked`); they must keep passing
   unchanged. Pinned by the full-suite run in Task 4.
5. **Opposite transfers** — two concurrent transfers between the same two
   resources in opposite directions must not deadlock. Pinned in Task 6.

---

### Task 1: Claimable agents configuration

**Files:**
- Modify: `conf/runtime.exs` (authz block)
- Modify: `src/zenflows/authz/config.ex`
- Modify: `src/zenflows/application.ex` (`start/2`)
- Test: `test/authz/config.test.exs`

**Interfaces:**
- Produces: `Zenflows.Authz.Config.claimable_agents() :: [String.t()]`,
  `Zenflows.Authz.Config.validate_claimable!([String.t()]) :: :ok` (raises).

- [ ] **Step 1: Write the failing tests** — append to `test/authz/config.test.exs`:

```elixir
test "claimable_agents defaults to empty" do
	assert Config.claimable_agents() == []
end

test "validate_claimable! accepts ULIDs and the empty list" do
	assert :ok = Config.validate_claimable!([])
	assert :ok = Config.validate_claimable!([Zenflows.DB.ID.gen(), Zenflows.DB.ID.gen()])
end

test "validate_claimable! refuses invalid ids" do
	assert_raise RuntimeError, ~r/AUTHZ_CLAIMABLE_AGENTS.*not-an-id/, fn ->
		Config.validate_claimable!([Zenflows.DB.ID.gen(), "not-an-id"])
	end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `./mann test test/authz/config.test.exs`
Expected: FAIL — `Config.claimable_agents/0 is undefined`.

- [ ] **Step 3: Implement**

In `conf/runtime.exs`, extend the `config :zenflows, Zenflows.Authz` call:

```elixir
config :zenflows, Zenflows.Authz,
	enforce: get_env("AUTHZ_ENFORCE", "true") != "false",
	allow_unchecked: get_env("AUTHZ_ALLOW_UNCHECKED", authz_unchecked_default) == "true",
	claimable_agents:
		get_env("AUTHZ_CLAIMABLE_AGENTS", "")
		|> String.split(",", trim: true)
		|> Enum.map(&String.trim/1)
		|> Enum.reject(&(&1 == ""))
```

In `src/zenflows/authz/config.ex` add before the final `end`:

```elixir
@doc "Agents whose resources anyone may claim (e.g. the LOSH import agent)."
@spec claimable_agents() :: [String.t()]
def claimable_agents() do
	Application.get_env(:zenflows, Zenflows.Authz, [])
	|> Keyword.get(:claimable_agents, [])
end

@doc "Raise unless every claimable agent id is a valid ULID."
@spec validate_claimable!([String.t()]) :: :ok
def validate_claimable!(ids) do
	case Enum.reject(ids, &match?({:ok, _}, Zenflows.DB.ID.cast(&1))) do
		[] -> :ok
		bad -> raise "AUTHZ_CLAIMABLE_AGENTS contains invalid agent ids: #{Enum.join(bad, ", ")}"
	end
end
```

In `src/zenflows/application.ex` `start/2`, right after
`:ok = Zenflows.Authz.Config.validate!()`, add:

```elixir
	:ok = Zenflows.Authz.Config.validate_claimable!(Zenflows.Authz.Config.claimable_agents())
```

- [ ] **Step 4: Run tests**

Run: `./mann test test/authz/config.test.exs`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add conf/runtime.exs src/zenflows/authz/config.ex src/zenflows/application.ex test/authz/config.test.exs
git commit -m "feat(authz): configurable claimable agents" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Pure event policy and facts struct

**Files:**
- Create: `src/zenflows/authz/event_facts.ex` (struct only in this task)
- Create: `src/zenflows/authz/event_policy.ex`
- Test: `test/authz/event_policy.test.exs`

**Interfaces:**
- Produces:
  - `%Zenflows.Authz.EventFacts{action, provider_id, receiver_id, source_id, event, touched, resources, controls, contained, admin_of, claimable}`
    — defaults: `nil, nil, nil, nil, nil, %{changes: [], references: [], creates: :none}, %{}, %{}, %{}, MapSet.new(), MapSet.new()`.
    `controls :: %{resource_id => %ResourceControl{}}`,
    `contained :: %{changed_resource_id => [contained_resource_id]}`.
  - `EventPolicy.actions() :: [String.t()]`, `EventPolicy.kind(action) :: :create | :change | :transfer | :reference | :none | :unsupported`
  - `EventPolicy.touched(changes :: map()) :: %{changes: [id], references: [id], creates: :none | :resource | :destination}`
  - `EventPolicy.decide(person_id, "event.create" | "event.update", EventFacts.t()) :: :ok | {:error, :forbidden, :agent | :resource | :claim | :unsupported}`
  - `EventPolicy.claim?(person_id, EventFacts.t()) :: boolean()`

- [ ] **Step 1: Write the failing test** — `test/authz/event_policy.test.exs`:

```elixir
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
```

- [ ] **Step 2: Run to verify failure**

Run: `./mann test test/authz/event_policy.test.exs`
Expected: compile error — `Zenflows.Authz.EventFacts` not available.

- [ ] **Step 3: Implement**

`src/zenflows/authz/event_facts.ex` (header, then):

```elixir
defmodule Zenflows.Authz.EventFacts do
@moduledoc """
Everything an event decision may look at.  `EconomicEvent.Domain`
loads it with row locks before the event is written.
"""

alias Zenflows.Authz.ResourceControl

@type t() :: %__MODULE__{
	action: nil | String.t(),
	provider_id: nil | String.t(),
	receiver_id: nil | String.t(),
	source_id: nil | String.t(),
	event: nil | struct(),
	touched: Zenflows.Authz.EventPolicy.touched(),
	resources: %{String.t() => struct()},
	controls: %{String.t() => ResourceControl.t()},
	contained: %{String.t() => [String.t()]},
	admin_of: MapSet.t(String.t()),
	claimable: MapSet.t(String.t()),
}

defstruct action: nil,
	provider_id: nil,
	receiver_id: nil,
	source_id: nil,
	event: nil,
	touched: %{changes: [], references: [], creates: :none},
	resources: %{},
	controls: %{},
	contained: %{},
	admin_of: MapSet.new(),
	claimable: MapSet.new()
end
```

`src/zenflows/authz/event_policy.ex` (header, then):

```elixir
defmodule Zenflows.Authz.EventPolicy do
@moduledoc """
Who may emit which economic event.  Pure: everything comes from
`Zenflows.Authz.EventFacts`.

- Agent rule: the signer acts for the provider or the receiver.
- Resource rule: the signer controls every resource the event changes
  (and, for containers, every contained resource).
- Claim rule: resources of a claimable agent may be moved by a
  transfer-type event into a new resource of the signer.
"""

alias Zenflows.Authz.EventFacts

@kinds %{
	"raise" => :create, "produce" => :create,
	"lower" => :change, "consume" => :change, "accept" => :change,
	"modify" => :change, "pickup" => :change, "dropoff" => :change,
	"transfer" => :transfer, "transferAllRights" => :transfer,
	"transferCustody" => :transfer, "move" => :transfer,
	"cite" => :reference, "use" => :reference,
	"work" => :none, "deliverService" => :none,
	"combine" => :unsupported, "separate" => :unsupported,
}

@claim_actions ~w[transfer transferAllRights transferCustody]

@type kind() :: :create | :change | :transfer | :reference | :none | :unsupported
@type touched() :: %{
	changes: [String.t()],
	references: [String.t()],
	creates: :none | :resource | :destination,
}
@type rule() :: :agent | :resource | :claim | :unsupported

@spec actions() :: [String.t()]
def actions(), do: Map.keys(@kinds)

@spec kind(nil | String.t()) :: kind()
def kind(action), do: Map.get(@kinds, action, :unsupported)

@doc "Resources an event with these (validated changeset) changes touches."
@spec touched(map()) :: touched()
def touched(changes) do
	res = Map.get(changes, :resource_inventoried_as_id)
	to_res = Map.get(changes, :to_resource_inventoried_as_id)
	case kind(Map.get(changes, :action_id)) do
		:create ->
			creates = if Map.get(changes, :resource_conforms_to_id), do: :resource, else: :none
			%{changes: List.wrap(res), references: [], creates: creates}
		:change ->
			%{changes: List.wrap(res), references: [], creates: :none}
		:transfer ->
			creates = if to_res, do: :none, else: :destination
			%{changes: Enum.reject([res, to_res], &is_nil/1), references: [], creates: creates}
		:reference ->
			%{changes: [], references: List.wrap(res), creates: :none}
		_ ->
			%{changes: [], references: [], creates: :none}
	end
end

@spec decide(String.t(), String.t(), EventFacts.t()) :: :ok | {:error, :forbidden, rule()}
def decide(pid, "event.update", %EventFacts{event: %{provider_id: p, receiver_id: r}} = f) do
	if acts_for?(pid, f, p) or acts_for?(pid, f, r),
		do: :ok,
		else: {:error, :forbidden, :agent}
end
def decide(pid, "event.create", %EventFacts{} = f) do
	cond do
		kind(f.action) == :unsupported ->
			{:error, :forbidden, :unsupported}
		not (acts_for?(pid, f, f.provider_id) or acts_for?(pid, f, f.receiver_id)) ->
			{:error, :forbidden, :agent}
		true ->
			check_changes(pid, f)
	end
end
def decide(_pid, _action, _facts), do: {:error, :forbidden, :agent}

@doc "Whether an authorized `event.create` was a claim (for the permission log)."
@spec claim?(String.t(), EventFacts.t()) :: boolean()
def claim?(pid, %EventFacts{source_id: src} = f) do
	src != nil and claimable_source?(f, src) and not controls_all?(pid, f, src)
		and claim_ok?(pid, f, src)
end

defp check_changes(pid, f) do
	Enum.reduce_while(f.touched.changes, :ok, fn id, :ok ->
		case change_ok(pid, f, id) do
			:ok -> {:cont, :ok}
			err -> {:halt, err}
		end
	end)
end

defp change_ok(pid, f, id) do
	cond do
		controls_all?(pid, f, id) -> :ok
		claimable_source?(f, id) ->
			if claim_ok?(pid, f, id), do: :ok, else: {:error, :forbidden, :claim}
		true -> {:error, :forbidden, :resource}
	end
end

# The resource and everything it contains.
defp controls_all?(pid, f, id),
	do: Enum.all?([id | Map.get(f.contained, id, [])], &controls?(pid, f, &1))

defp controls?(pid, f, id) do
	case Map.get(f.controls, id) do
		%{controller_id: cid} -> acts_for?(pid, f, cid)
		nil -> false
	end
end

defp claimable_source?(f, id) do
	case Map.get(f.controls, id) do
		%{controller_id: cid} -> MapSet.member?(f.claimable, cid)
		nil -> false
	end
end

defp claim_ok?(pid, f, id) do
	f.action in @claim_actions
		and f.touched.creates == :destination
		and id == f.source_id
		and acts_for?(pid, f, f.receiver_id)
		and Map.get(f.contained, id, []) == []
end

defp acts_for?(_pid, _f, nil), do: false
defp acts_for?(pid, f, id), do: id == pid or MapSet.member?(f.admin_of, id)
end
```

- [ ] **Step 4: Run tests**

Run: `./mann test test/authz/event_policy.test.exs`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add src/zenflows/authz/event_facts.ex src/zenflows/authz/event_policy.ex test/authz/event_policy.test.exs
git commit -m "feat(authz): pure event policy with action table" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Event facts loader; Policy and Authz integration

**Files:**
- Modify: `src/zenflows/authz/event_facts.ex` (add `load/3`, `for_event/3`)
- Modify: `src/zenflows/authz/policy.ex` (actions, EventFacts clause)
- Modify: `src/zenflows/authz.ex` (rule in telemetry; EventFacts target id)
- Modify: `src/zenflows/authz/execution_context.ex` (`@service_actions`)
- Test: `test/authz/event_facts.test.exs`, `test/authz/authz.test.exs`

**Interfaces:**
- Consumes: Task 2; `Facts.admin_of/3`; `Config.claimable_agents/0`.
- Produces:
  - `EventFacts.load(repo, ctx, changes :: map()) :: EventFacts.t()`
  - `EventFacts.for_event(repo, ctx, event_id) :: EventFacts.t()`
  - `Policy.authorize/4` accepts `%EventFacts{}` for `"event.create"`/`"event.update"` and may return `{:error, :forbidden, rule}`.
  - `Authz.authorize/4` returns `:ok | {:error, :forbidden | :unauthenticated}`; telemetry metadata has `rule`.

- [ ] **Step 1: Write the failing tests**

`test/authz/event_facts.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.EventFacts do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.Authz.{EventFacts, ResourceControl}
alias Zenflows.VF.EconomicEvent

setup do
	alice = Factory.insert!(:person)
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	raise! = fn ->
		EconomicEvent.Domain.create!(Factory.ctx(alice), %{
			action_id: "raise", provider_id: alice.id, receiver_id: alice.id,
			resource_conforms_to_id: spec.id,
			resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
			has_point_in_time: Factory.now(),
		}, %{name: Factory.str("r")}).resource_inventoried_as_id
	end
	%{alice: alice, r1: raise!.(), r2: raise!.()}
end

test "load/3 collects resources, controls, contents and admin rows", c do
	org = Factory.insert!(:organization)
	Factory.insert_admin!(c.alice, org)
	Repo.update_all(from(r in Zenflows.VF.EconomicResource, where: r.id == ^c.r2),
		set: [contained_in_id: c.r1])
	Repo.update_all(from(x in ResourceControl, where: x.resource_id == ^c.r1),
		set: [controller_id: org.id])

	f = EventFacts.load(Repo, Factory.ctx(c.alice), %{
		action_id: "transfer", provider_id: c.alice.id, receiver_id: c.alice.id,
		resource_inventoried_as_id: c.r1,
	})

	assert f.action == "transfer" and f.source_id == c.r1
	assert f.touched.changes == [c.r1] and f.touched.creates == :destination
	assert f.contained == %{c.r1 => [c.r2]}
	assert Map.keys(f.controls) |> Enum.sort() == Enum.sort([c.r1, c.r2])
	assert Map.has_key?(f.resources, c.r1) and Map.has_key?(f.resources, c.r2)
	assert MapSet.member?(f.admin_of, org.id)
end

test "for_event/3 loads the event and its agents' admin rows", c do
	evt = Repo.one!(from e in EconomicEvent, where: e.resource_inventoried_as_id == ^c.r1, limit: 1)
	assert %EventFacts{event: %EconomicEvent{id: id}} = EventFacts.for_event(Repo, Factory.ctx(c.alice), evt.id)
	assert id == evt.id
	assert %EventFacts{event: nil} = EventFacts.for_event(Repo, Factory.ctx(c.alice), Factory.id())
end
end
```

Append to `test/authz/authz.test.exs` (inside the module):

```elixir
test "event decisions go through Authz.authorize with a rule in telemetry", %{alice: alice} do
	ref = make_ref()
	pid = self()
	:telemetry.attach("authz-evt-#{inspect(ref)}", [:zenflows, :authz, :deny],
		fn _, _, meta, _ -> send(pid, {:deny, meta}) end, nil)
	on_exit(fn -> :telemetry.detach("authz-evt-#{inspect(ref)}") end)

	other = Factory.id()
	f = %Zenflows.Authz.EventFacts{action: "work", provider_id: other, receiver_id: other}
	assert {:error, :forbidden} = Authz.authorize(Factory.ctx(alice), "event.create", f)
	assert_received {:deny, %{action: "event.create", rule: :agent, reason: :forbidden}}
	assert :ok = Authz.authorize(Factory.ctx(), "event.create", f)
end
```

- [ ] **Step 2: Run to verify failure**

Run: `./mann test test/authz/event_facts.test.exs test/authz/authz.test.exs`
Expected: failures (`EventFacts.load/3` undefined; policy rejects EventFacts).

- [ ] **Step 3: Implement the loader** — in `event_facts.ex` add after the
existing `alias`:

```elixir
import Ecto.Query

alias Zenflows.Authz.{Config, EventPolicy, ExecutionContext, Facts}
alias Zenflows.VF.{EconomicEvent, EconomicResource}
```

and before the final `end`:

```elixir
@doc """
Facts for `event.create`.  Locks, in this order: touched resources and
the resources contained in changed ones (one query, ascending id,
FOR UPDATE), their control rows (ascending, FOR UPDATE), then the
admin rows the decision needs (FOR SHARE).
"""
@spec load(Ecto.Repo.t(), ExecutionContext.t(), map()) :: t()
def load(repo, ctx, changes) do
	touched = EventPolicy.touched(changes)
	contained = contained_of(repo, touched.changes)
	inner = contained |> Map.values() |> List.flatten()

	resources =
		lock_resources(repo, Enum.uniq(touched.changes ++ touched.references ++ inner))
	controls = lock_controls(repo, Enum.uniq(touched.changes ++ inner))

	provider = Map.get(changes, :provider_id)
	receiver = Map.get(changes, :receiver_id)
	admin_ids = [provider, receiver | Enum.map(Map.values(controls), & &1.controller_id)]

	%__MODULE__{
		action: Map.get(changes, :action_id),
		provider_id: provider,
		receiver_id: receiver,
		source_id: Map.get(changes, :resource_inventoried_as_id),
		touched: touched,
		resources: resources,
		controls: controls,
		contained: contained,
		admin_of: Facts.admin_of(repo, ctx, admin_ids),
		claimable: MapSet.new(Config.claimable_agents()),
	}
end

@doc "Facts for `event.update`: the stored event (FOR UPDATE) and its agents."
@spec for_event(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_event(repo, ctx, id) do
	evt = repo.one(from e in EconomicEvent, where: e.id == ^id, lock: "FOR UPDATE")
	ids = if evt, do: [evt.provider_id, evt.receiver_id], else: []
	%__MODULE__{event: evt, admin_of: Facts.admin_of(repo, ctx, ids)}
end

defp contained_of(_repo, []), do: %{}
defp contained_of(repo, ids) do
	from(r in EconomicResource, where: r.contained_in_id in ^ids,
		select: {r.contained_in_id, r.id})
	|> repo.all()
	|> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
end

defp lock_resources(_repo, []), do: %{}
defp lock_resources(repo, ids) do
	from(r in EconomicResource, where: r.id in ^ids, order_by: r.id, lock: "FOR UPDATE")
	|> repo.all()
	|> Map.new(&{&1.id, &1})
end

defp lock_controls(_repo, []), do: %{}
defp lock_controls(repo, ids) do
	from(c in ResourceControl, where: c.resource_id in ^ids,
		order_by: c.resource_id, lock: "FOR UPDATE")
	|> repo.all()
	|> Map.new(&{&1.resource_id, &1})
end
```

(If the `contained` map values come back in non-deterministic order,
sort each list: `Map.new(groups, fn {k, v} -> {k, Enum.sort(v)} end)`.)

- [ ] **Step 4: Policy, Authz, service actions**

`src/zenflows/authz/policy.ex`:
- alias `Zenflows.Authz.{Config, EventFacts, EventPolicy, ExecutionContext, Facts}`;
- add `event.create event.update` to `@actions`;
- replace `authorize/4` with:

```elixir
@spec authorize(ExecutionContext.t(), String.t(), Facts.t() | EventFacts.t(), Config.opts())
	:: :ok | {:error, :forbidden | :unauthenticated} | {:error, :forbidden, EventPolicy.rule()}
def authorize(%ExecutionContext{principal: %Person{id: pid}}, action, %EventFacts{} = f, _opts)
		when action in ~w[event.create event.update],
	do: EventPolicy.decide(pid, action, f)
def authorize(%ExecutionContext{principal: principal}, action, facts, opts)
		when is_struct(facts, Facts) or is_struct(facts, EventFacts) do
	if action in @actions,
		do: decide(principal, action, facts, opts),
		else: {:error, :forbidden}
end
```

`src/zenflows/authz.ex`: alias `EventFacts`; widen the `authorize/4` and
`multi_authorize/5` specs to `Facts.t() | EventFacts.t()`; replace the
body of `authorize/4` with:

```elixir
	case Policy.authorize(ctx, action, facts, opts) do
		:ok -> :ok
		{:error, reason} -> deny(ctx, action, facts, reason, nil, opts)
		{:error, reason, rule} -> deny(ctx, action, facts, reason, rule, opts)
	end
```

and add / change the private helpers:

```elixir
defp deny(ctx, action, facts, reason, rule, opts) do
	enforced? = Keyword.get(opts, :enforce, true)
	report_deny(ctx, action, facts, reason, rule, enforced?)
	if enforced?, do: {:error, reason}, else: :ok
end
```

`report_deny/6` adds `rule: rule` to the metadata map; add
`defp target_id(%EventFacts{event: %{id: id}}), do: id` and
`defp target_id(%EventFacts{source_id: id}), do: id` before the
`defp target_id(_), do: nil` clause.

`src/zenflows/authz/execution_context.ex` `@service_actions`: add
`event.create` to `import:` and `migration:`.

- [ ] **Step 5: Run tests**

Run: `./mann test test/authz/`
Expected: all pass (the earlier telemetry test still matches: its pattern
is a partial map).

- [ ] **Step 6: Commit**

```bash
git add src/zenflows/authz/event_facts.ex src/zenflows/authz/policy.ex src/zenflows/authz.ex src/zenflows/authz/execution_context.ex test/authz/event_facts.test.exs test/authz/authz.test.exs
git commit -m "feat(authz): event facts loader and policy integration" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Authorize event creation; receiver control; claims

**Files:**
- Modify: `src/zenflows/vf/economic_event/domain.ex` (`multi_insert/5`, resource-creation call sites)
- Modify: `src/zenflows/vf/economic_resource/domain.ex` (`multi_insert/5`)
- Modify: `src/zenflows/authz/resource_control/domain.ex` (`multi_on_create/4`)
- Modify: `test/authz/resource_control.test.exs` (three slice-1 tests, see Step 6)
- Test: `test/authz/events.test.exs`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: `EconomicResource.Domain.multi_insert(m, ctx, key, params, opts \\ [])`
  (no default for `key` any more; `opts`: `controller:`, `event_id:`),
  `ResourceControl.Domain.multi_on_create(m, ctx, res_key, opts \\ [])`.

- [ ] **Step 1: Write the failing tests** — `test/authz/events.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Events do
use ZenflowsTest.Help.EctoCase, async: false

alias Zenflows.Authz.{PermissionLog, ResourceControl}
alias Zenflows.VF.{EconomicEvent, EconomicResource}

setup do
	prev = Application.get_env(:zenflows, Zenflows.Authz)
	on_exit(fn -> Application.put_env(:zenflows, Zenflows.Authz, prev) end)
	%{
		alice: Factory.insert!(:person),
		bob: Factory.insert!(:person),
		carol: Factory.insert!(:person),
		unit: Factory.insert!(:unit),
		spec: Factory.insert!(:resource_specification),
	}
end

defp raise!(c, signer, agent, attrs \\ %{}) do
	EconomicEvent.Domain.create(Factory.ctx(signer), Map.merge(%{
		action_id: "raise", provider_id: agent.id, receiver_id: agent.id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, attrs), %{name: Factory.str("res")})
end

defp res_of!(c, owner) do
	{:ok, evt} = raise!(c, owner, owner)
	EconomicResource.Domain.one!(evt.resource_inventoried_as_id)
end

defp event(c, signer, attrs, res_params \\ nil) do
	EconomicEvent.Domain.create(Factory.ctx(signer), Map.merge(%{
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, attrs), res_params)
end

defp control(id), do: Repo.get_by(ResourceControl, resource_id: id)

test "Bob cannot raise in Alice's name", c do
	assert {:error, :forbidden} = raise!(c, c.bob, c.alice)
end

test "Bob cannot lower Alice's resource as provider or as receiver", c do
	res = res_of!(c, c.alice)
	assert {:error, :forbidden} =
		event(c, c.bob, %{action_id: "lower", provider_id: c.bob.id, receiver_id: c.bob.id, resource_inventoried_as_id: res.id})
	assert {:error, :forbidden} =
		event(c, c.bob, %{action_id: "lower", provider_id: c.alice.id, receiver_id: c.alice.id, resource_inventoried_as_id: res.id})
	assert Decimal.eq?(EconomicResource.Domain.one!(res.id).onhand_quantity_has_numerical_value, 1)
end

test "Bob cannot pull Alice's resource to himself", c do
	res = res_of!(c, c.alice)
	assert {:error, :forbidden} =
		event(c, c.bob, %{action_id: "transfer", provider_id: c.alice.id, receiver_id: c.bob.id,
			resource_inventoried_as_id: res.id}, %{name: "stolen"})
	assert EconomicResource.Domain.one!(res.id).primary_accountable_id == c.alice.id
end

test "Bob may cite Alice's resource in his own event", c do
	res = res_of!(c, c.alice)
	assert {:ok, %EconomicEvent{}} =
		event(c, c.bob, %{action_id: "cite", input_of_id: Factory.insert!(:process).id,
			provider_id: c.bob.id, receiver_id: c.bob.id, resource_inventoried_as_id: res.id})
end

test "transfer gives control of the new resource to the receiver, logged with event_id", c do
	res = res_of!(c, c.alice)
	{:ok, evt} = event(c, c.alice, %{action_id: "transfer", provider_id: c.alice.id,
		receiver_id: c.carol.id, resource_inventoried_as_id: res.id}, %{name: "gift"})
	assert %ResourceControl{controller_id: cid} = control(evt.to_resource_inventoried_as_id)
	assert cid == c.carol.id
	evt_id = evt.id
	assert [%PermissionLog{after: %{"event_id" => ^evt_id}}] =
		Repo.all(from l in PermissionLog, where: l.target_id == ^evt.to_resource_inventoried_as_id
			and l.action == "resource_control.set")
end

test "admin of the controlling org may act; a revoked admin may not", c do
	org = Factory.insert!(:organization)
	rel = Factory.insert_admin!(c.alice, org)
	{:ok, evt} = raise!(c, c.alice, org)
	res_id = evt.resource_inventoried_as_id
	assert control(res_id).controller_id == org.id
	assert {:ok, _} = event(c, c.alice, %{action_id: "lower", provider_id: org.id,
		receiver_id: org.id, resource_quantity: %{has_numerical_value: "0.5", has_unit_id: c.unit.id},
		resource_inventoried_as_id: res_id})
	rel |> Ecto.Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update!()
	assert {:error, :forbidden} = event(c, c.alice, %{action_id: "lower", provider_id: org.id,
		receiver_id: org.id, resource_quantity: %{has_numerical_value: "0.5", has_unit_id: c.unit.id},
		resource_inventoried_as_id: res_id})
end

test "container whose contents someone else controls blocks the transfer", c do
	box = res_of!(c, c.alice)
	item = res_of!(c, c.bob)
	Repo.update_all(from(r in EconomicResource, where: r.id == ^item.id), set: [contained_in_id: box.id])
	assert {:error, :forbidden} =
		event(c, c.alice, %{action_id: "transferCustody", provider_id: c.alice.id,
			receiver_id: c.carol.id, resource_inventoried_as_id: box.id}, %{name: "box"})
end

test "combine is denied", c do
	assert {:error, :forbidden} =
		event(c, c.alice, %{action_id: "combine", provider_id: c.alice.id, receiver_id: c.alice.id})
end

test "invalid params still return the changeset error", c do
	assert {:error, %Ecto.Changeset{}} = EconomicEvent.Domain.create(Factory.ctx(c.bob), %{action_id: "raise"})
end

describe "claims" do
	setup c do
		losh = Factory.insert!(:person)
		Application.put_env(:zenflows, Zenflows.Authz,
			Keyword.put(Application.get_env(:zenflows, Zenflows.Authz), :claimable_agents, [losh.id]))
		%{losh: losh, losh_res: res_of!(c, losh)}
	end

	test "anyone may claim to themselves; claimer controls the copy; logged once", c do
		{:ok, evt} = event(c, c.bob, %{action_id: "transfer", provider_id: c.losh.id,
			receiver_id: c.bob.id, resource_inventoried_as_id: c.losh_res.id}, %{name: "mine"})
		assert control(evt.to_resource_inventoried_as_id).controller_id == c.bob.id
		new_id = evt.to_resource_inventoried_as_id
		assert [%PermissionLog{actor_id: actor, target_id: tid, after: %{"resource_id" => ^new_id}}] =
			Repo.all(from l in PermissionLog, where: l.action == "resource.claim")
		assert actor == c.bob.id and tid == c.losh_res.id
	end

	test "claim for someone else, or into an existing resource, is denied", c do
		assert {:error, :forbidden} = event(c, c.bob, %{action_id: "transfer", provider_id: c.losh.id,
			receiver_id: c.carol.id, resource_inventoried_as_id: c.losh_res.id}, %{name: "x"})
		mine = res_of!(c, c.bob)
		assert {:error, :forbidden} = event(c, c.bob, %{action_id: "transfer", provider_id: c.losh.id,
			receiver_id: c.bob.id, resource_inventoried_as_id: c.losh_res.id,
			to_resource_inventoried_as_id: mine.id})
	end

	test "nothing is claimable with an empty list", c do
		Application.put_env(:zenflows, Zenflows.Authz,
			Keyword.put(Application.get_env(:zenflows, Zenflows.Authz), :claimable_agents, []))
		assert {:error, :forbidden} = event(c, c.bob, %{action_id: "transfer", provider_id: c.losh.id,
			receiver_id: c.bob.id, resource_inventoried_as_id: c.losh_res.id}, %{name: "x"})
	end
end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `./mann test test/authz/events.test.exs`
Expected: several failures (events are not authorized yet; the transfer
copy is controlled by the signer).

- [ ] **Step 3: Resource creation options**

`src/zenflows/authz/resource_control/domain.ex`: replace the two
`multi_on_create` clauses with

```elixir
@spec multi_on_create(Multi.t(), ExecutionContext.t(), term(), Keyword.t()) :: Multi.t()
def multi_on_create(m, ctx, res_key, opts \\ [])
def multi_on_create(m, %ExecutionContext{principal: {:service, :migration, _}}, _res_key, _opts), do: m
def multi_on_create(m, ctx, res_key, opts) do
	m
	|> Multi.run("#{res_key}.control", fn repo, changes ->
		%EconomicResource{} = res = Map.fetch!(changes, res_key)
		with :ok <- check_anonymous(ctx) do
			{controller_id, source} =
				case Keyword.get(opts, :controller) do
					nil -> controller_for(repo, ctx, res)
					cid -> {cid, :creation}
				end
			%{resource_id: res.id, controller_id: controller_id, source: source}
			|> ResourceControl.changeset()
			|> repo.insert()
		end
	end)
	|> Log.multi_insert("#{res_key}.control.log", ctx, fn changes ->
		control = Map.fetch!(changes, "#{res_key}.control")
		res = Map.fetch!(changes, res_key)
		%{
			action: "resource_control.set",
			target_type: "economic_resource",
			target_id: control.resource_id,
			subject_id: control.controller_id,
			after:
				%{
					controller_id: control.controller_id,
					source: control.source,
					declared_receiver_id: res.primary_accountable_id,
				}
				|> put_present(:event_id, Keyword.get(opts, :event_id)),
		}
	end)
end

defp put_present(map, _key, nil), do: map
defp put_present(map, key, value), do: Map.put(map, key, value)
```

Keep the existing `@doc` text above it and add one sentence:
"`controller:` overrides the controller (transfer-type events give the new
resource to the receiver); `event_id:` is recorded in the log entry."

`src/zenflows/vf/economic_resource/domain.ex`: replace `multi_insert/4` with

```elixir
@spec multi_insert(Multi.t(), ExecutionContext.t(), term(), Schema.params(), Keyword.t()) :: Multi.t()
def multi_insert(m, ctx, key, params, opts \\ []) do
	m
	|> Multi.insert(key, EconomicResource.changeset(params))
	|> File.Domain.multi_insert(key, :images, :economic_resource_id)
	|> ResourceControl.Domain.multi_on_create(ctx, key, opts)
end
```

(Run `grep -rn "EconomicResource.Domain.multi_insert" src test` first; all
callers already pass the key explicitly.)

In `src/zenflows/vf/economic_event/domain.ex`:

```bash
sed -i '' -E 's/EconomicResource\.Domain\.multi_insert\(ctx, "#\{key\}\.eco_res", res_params\)/EconomicResource.Domain.multi_insert(ctx, "#{key}.eco_res", res_params, event_id: evt.id)/' src/zenflows/vf/economic_event/domain.ex
sed -i '' -E 's/EconomicResource\.Domain\.multi_insert\(ctx, "#\{key\}\.to_eco_res", res_params\)/EconomicResource.Domain.multi_insert(ctx, "#{key}.to_eco_res", res_params, controller: evt.receiver_id, event_id: evt.id)/' src/zenflows/vf/economic_event/domain.ex
grep -n "EconomicResource.Domain.multi_insert" src/zenflows/vf/economic_event/domain.ex
```

Expected: one `eco_res` line with `event_id:` and four `to_eco_res` lines
with `controller: evt.receiver_id, event_id: evt.id`.

- [ ] **Step 4: Authorize before the insert, log claims** — in
`src/zenflows/vf/economic_event/domain.ex` add

```elixir
alias Zenflows.Authz
alias Zenflows.Authz.{EventFacts, EventPolicy, Log}
```

and replace `multi_insert/5` with

```elixir
@spec multi_insert(Multi.t(), ExecutionContext.t(), term(), Schema.params(), nil | Schema.params())
	:: Multi.t()
def multi_insert(m, ctx, key \\ multi_key(), evt_params, res_params) do
	cset = EconomicEvent.changeset(evt_params)
	m
	|> Multi.run("#{key}.authz", fn repo, _ -> authorize_create(repo, ctx, cset) end)
	|> Multi.insert("#{key}.created", cset)
	|> Multi.merge(&handle_insert(ctx, key, Map.fetch!(&1, "#{key}.created"), res_params))
	|> multi_log_claim(ctx, key)
end

# An invalid changeset is left to `Multi.insert` so callers keep getting
# the changeset error; nothing is locked for it.
defp authorize_create(_repo, _ctx, %Changeset{valid?: false}), do: {:ok, nil}
defp authorize_create(repo, ctx, cset) do
	facts = EventFacts.load(repo, ctx, cset.changes)
	with :ok <- Authz.authorize(ctx, "event.create", facts), do: {:ok, facts}
end

defp multi_log_claim(m, ctx, key) do
	Log.multi_insert(m, "#{key}.claim.log", ctx, fn changes ->
		facts = Map.fetch!(changes, "#{key}.authz")
		pid = ExecutionContext.actor_id(ctx)
		if facts && pid && EventPolicy.claim?(pid, facts) do
			evt = Map.fetch!(changes, key)
			%{
				action: "resource.claim",
				target_type: "economic_resource",
				target_id: facts.source_id,
				subject_id: evt.receiver_id,
				before: %{controller_id: Map.fetch!(facts.controls, facts.source_id).controller_id},
				after: %{
					controller_id: evt.receiver_id,
					event_id: evt.id,
					resource_id: evt.to_resource_inventoried_as_id,
				},
			}
		end
	end)
end
```

- [ ] **Step 5: Run the new tests**

Run: `./mann test test/authz/events.test.exs`
Expected: all pass.

- [ ] **Step 6: Update slice-1 tests whose behaviour changed (spec delta 4)**

In `test/authz/resource_control.test.exs`:
- "foreign receiver: verified creator controls; declared receiver recorded" →
  rename to "foreign receiver: raising in another agent's name is forbidden"
  and assert `{:error, :forbidden} = EconomicEvent.Domain.create(Factory.ctx(c.bob), <raise params with receiver alice>, %{name: "x"})`.
- "org receiver: creator controls when not an admin" → rename to
  "org receiver: non-admin cannot raise for the org" and assert
  `{:error, :forbidden}` the same way.
- "transfer to another agent: new resource controlled by the creator" →
  rename to "...controlled by the receiver" and assert the controller is
  `c.carol.id`.

Then run `grep -rn "declared_receiver" test/authz` and make sure no other
test relied on a person raising for someone else.

- [ ] **Step 7: Full suite**

Run: `./mann test`
Expected: only the 7 known failures. If an existing test fails with
`{:error, :forbidden}`, check whether it signs with a Person context for
another agent (behaviour change, update the test and list it in the
report) or reveals a policy bug (stop and report).

- [ ] **Step 8: Commit**

```bash
git add src/zenflows/vf/economic_event/domain.ex src/zenflows/vf/economic_resource/domain.ex src/zenflows/authz/resource_control/domain.ex test/authz/events.test.exs test/authz/resource_control.test.exs
git commit -m "feat(authz): authorize economic events before they are written" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: updateEconomicEvent, GraphQL wiring, guards

**Files:**
- Modify: `src/zenflows/vf/economic_event/domain.ex` (`update/3`, `update!/3`, `multi_update/5`)
- Modify: `src/zenflows/vf/economic_event/resolv.ex`
- Modify: `src/zenflows/vf/economic_event/type.ex` (meta authz)
- Modify: `test/authz/guard.test.exs` (pending list), `test/authz/log_content.test.exs` (allowed keys)
- Test: `test/authz/events_api.test.exs`

**Interfaces:**
- Consumes: `EventFacts.for_event/3`; `AbsinCase.run_as!/3`.
- Produces: `EconomicEvent.Domain.update(ctx, id, params)`; GraphQL
  `createEconomicEvent` (`meta authz: "event.create"`),
  `updateEconomicEvent` (`meta authz: "event.update"`, argument `event`).

- [ ] **Step 1: Write the failing tests** — `test/authz/events_api.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.EventsAPI do
use ZenflowsTest.Help.AbsinCase, async: false

alias Zenflows.VF.{EconomicEvent, EconomicResource}

@forbidden %{message: "forbidden", extensions: %{code: "FORBIDDEN"}}

setup do
	prev = Application.get_env(:zenflows, Zenflows.Authz)
	on_exit(fn -> Application.put_env(:zenflows, Zenflows.Authz, prev) end)
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person),
		unit: Factory.insert!(:unit), spec: Factory.insert!(:resource_specification)}
end

defp raise!(c, owner) do
	EconomicEvent.Domain.create!(Factory.ctx(owner), %{
		action_id: "raise", provider_id: owner.id, receiver_id: owner.id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: Factory.str("res")})
end

test "acceptProposal-shaped document succeeds for the owner", c do
	origin = raise!(c, c.alice).resource_inventoried_as_id
	fork = raise!(c, c.bob).resource_inventoried_as_id
	process = Factory.insert!(:process).id
	assert %{data: %{"cite" => %{"economicEvent" => %{"id" => _}},
			"accept" => %{"economicEvent" => %{"id" => _}},
			"modify" => %{"economicEvent" => %{"id" => _}}}} =
		run_as!(c.alice, """
			mutation ($process: ID!, $owner: ID!, $proposer: ID!, $unit: ID!, $fork: ID!, $origin: ID!, $now: DateTime!) {
				cite: createEconomicEvent(event: {action: "cite", inputOf: $process, provider: $proposer, receiver: $owner,
					resourceInventoriedAs: $fork, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}, hasPointInTime: $now}) { economicEvent { id } }
				accept: createEconomicEvent(event: {action: "accept", inputOf: $process, provider: $owner, receiver: $owner,
					resourceInventoriedAs: $origin, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}, hasPointInTime: $now}) { economicEvent { id } }
				modify: createEconomicEvent(event: {action: "modify", outputOf: $process, provider: $owner, receiver: $owner,
					resourceInventoriedAs: $origin, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}, hasPointInTime: $now}) { economicEvent { id } }
			}
		""", vars: %{"process" => process, "owner" => c.alice.id, "proposer" => c.bob.id,
			"unit" => c.unit.id, "fork" => fork, "origin" => origin, "now" => Factory.iso_now()})
end

test "claim-shaped document succeeds for a listed agent", c do
	losh = Factory.insert!(:person)
	Application.put_env(:zenflows, Zenflows.Authz,
		Keyword.put(Application.get_env(:zenflows, Zenflows.Authz), :claimable_agents, [losh.id]))
	res = raise!(c, losh).resource_inventoried_as_id
	assert %{data: %{"createEconomicEvent" => %{"economicEvent" => %{"toResourceInventoriedAs" => %{"id" => _}}}}} =
		run_as!(c.bob, """
			mutation ($res: ID!, $losh: ID!, $agent: ID!, $unit: ID!, $now: DateTime!) {
				createEconomicEvent(event: {resourceInventoriedAs: $res, action: "transfer", provider: $losh, receiver: $agent,
					hasPointInTime: $now, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}},
					newInventoriedResource: {name: "claimed"}) {
					economicEvent { id toResourceInventoriedAs { id } }
				}
			}
		""", vars: %{"res" => res, "losh" => losh.id, "agent" => c.bob.id, "unit" => c.unit.id, "now" => Factory.iso_now()})
end

test "Bob cannot transfer Alice's resource to himself over GraphQL", c do
	res = raise!(c, c.alice).resource_inventoried_as_id
	assert %{data: nil, errors: [err]} =
		run_as!(c.bob, """
			mutation ($res: ID!, $alice: ID!, $bob: ID!, $unit: ID!, $now: DateTime!) {
				createEconomicEvent(event: {resourceInventoriedAs: $res, action: "transfer", provider: $alice, receiver: $bob,
					hasPointInTime: $now, resourceQuantity: {hasNumericalValue: 1, hasUnit: $unit}},
					newInventoriedResource: {name: "mine"}) { economicEvent { id } }
			}
		""", vars: %{"res" => res, "alice" => c.alice.id, "bob" => c.bob.id, "unit" => c.unit.id, "now" => Factory.iso_now()})
	assert Map.take(err, [:message, :extensions]) == @forbidden
	assert EconomicResource.Domain.one!(res).primary_accountable_id == c.alice.id
end

test "updateEconomicEvent: provider may edit the note, a stranger may not", c do
	evt = raise!(c, c.alice)
	doc = """
		mutation ($id: ID!) { updateEconomicEvent(event: {id: $id, note: "edited"}) { economicEvent { id note } } }
	"""
	assert %{data: nil, errors: [err]} = run_as!(c.bob, doc, vars: %{"id" => evt.id})
	assert Map.take(err, [:message, :extensions]) == @forbidden
	assert %{data: %{"updateEconomicEvent" => %{"economicEvent" => %{"note" => "edited"}}}} =
		run_as!(c.alice, doc, vars: %{"id" => evt.id})
end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `./mann test test/authz/events_api.test.exs`
Expected: the update test fails (resolver head mismatch / no authorization).

- [ ] **Step 3: Domain update with context** — in
`src/zenflows/vf/economic_event/domain.ex` replace `update/2`, `update!/2`,
`multi_update/4` with

```elixir
@spec update(ExecutionContext.t(), Schema.id(), Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, atom() | String.t() | Changeset.t()}
def update(%ExecutionContext{} = ctx, id, params) do
	key = multi_key()
	Multi.new()
	|> multi_update(ctx, id, params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec update!(ExecutionContext.t(), Schema.id(), Schema.params()) :: EconomicEvent.t()
def update!(ctx, id, params) do
	# `__MODULE__` because it confilicts with `import Ecto.Query`
	{:ok, value} = __MODULE__.update(ctx, id, params)
	value
end

@spec multi_update(Multi.t(), ExecutionContext.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, ctx, key \\ multi_key(), id, params) do
	m
	|> Multi.run("#{key}.authz", fn repo, _ ->
		facts = EventFacts.for_event(repo, ctx, id)
		with :ok <- Authz.authorize(ctx, "event.update", facts), do: {:ok, facts}
	end)
	|> Multi.run("#{key}.one", fn _, %{"#{key}.authz" => facts} ->
		if facts.event, do: {:ok, facts.event}, else: {:error, "not found"}
	end)
	|> Multi.update(key,
		&EconomicEvent.changeset(Map.fetch!(&1, "#{key}.one"), params))
end
```

(Keep `multi_one/3` if other code uses it: `grep -rn "EconomicEvent.Domain.multi_one" src test`.)

- [ ] **Step 4: Resolver and type**

`src/zenflows/vf/economic_event/resolv.ex`:

```elixir
def update_economic_event(%{event: %{id: id} = params}, res) do
	with {:ok, eco_evt} <- Domain.update(ExecutionContext.from_resolution(res), id, params) do
		{:ok, %{economic_event: eco_evt}}
	end
end
```

`src/zenflows/vf/economic_event/type.ex`: add `meta authz: "event.create"`
as the first line of `field :create_economic_event` and
`meta authz: "event.update"` in `field :update_economic_event`.

- [ ] **Step 5: Guards and log-content keys**

- `test/authz/guard.test.exs`: remove `create_economic_event update_economic_event` from `@pending`.
- `test/authz/log_content.test.exs`: `@allowed_keys` gains `event_id resource_id`.

- [ ] **Step 6: Run tests**

Run: `./mann test test/authz/ test/vf/economic_event`
Expected: all pass (if `Factory.iso_now/0` doesn't exist, use
`DateTime.utc_now() |> DateTime.to_iso8601()`).

Run: `./mann test`
Expected: only the 7 known failures.

- [ ] **Step 7: Commit**

```bash
git add src/zenflows/vf/economic_event/domain.ex src/zenflows/vf/economic_event/resolv.ex src/zenflows/vf/economic_event/type.ex test/authz/guard.test.exs test/authz/log_content.test.exs test/authz/events_api.test.exs
git commit -m "feat(authz): authorize updateEconomicEvent, wire event mutations" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Concurrency — opposite transfers and event vs revoke

**Files:**
- Test: `test/authz/concurrency_events.test.exs`

**Interfaces:**
- Consumes: everything above; patterns from `test/authz/concurrency_revoke.test.exs`
  (unboxed fixtures, try/after release of parked tasks, per-trial cleanup).

- [ ] **Step 1: Write the tests** — `test/authz/concurrency_events.test.exs`
(`use ExUnit.Case, async: false`; every DB call inside
`Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn -> ... end)`):

Fixtures helper `fixtures!/0` (unboxed): persons alice and bob
(`Person.changeset(%{name, user, email})` with unique strings), an
organization `org` with alice and bob as `org.admin`
(`%AgentRelationship{subject_id, object_id: org.id, in_scope_of_id: org.id,
relationship_id: Roles.id!(Repo, "org.admin")}`), a unit
(`Unit.changeset(%{label: s, symbol: s})`), a resource specification
(`ResourceSpecification.changeset(%{name: s})`), and two resources
`r1`, `r2` raised by alice for `org` with quantity 10
(`EconomicEvent.Domain.create!(ctx(alice), raise params, %{name: s})`).

Cleanup helper `cleanup!(fx)` (unboxed, in `after`/`on_exit`):

```elixir
ids = Repo.all(from r in EconomicResource, where: r.primary_accountable_id == ^fx.org.id or r.primary_accountable_id == ^fx.alice.id, select: r.id)
Repo.update_all(from(r in EconomicResource, where: r.id in ^ids), set: [previous_event_id: nil, contained_in_id: nil])
Repo.delete_all(from e in EconomicEvent, where: e.resource_inventoried_as_id in ^ids or e.to_resource_inventoried_as_id in ^ids)
Repo.delete_all(from r in EconomicResource, where: r.id in ^ids)
Repo.delete_all(from r in AgentRelationship, where: r.object_id == ^fx.org.id)
for x <- [fx.alice, fx.bob, fx.org, fx.unit, fx.spec], do: Repo.delete!(x)
Repo.query!("TRUNCATE zf_permission_log")
```

Test A — "opposite transfers between the same two resources do not
deadlock": 15 trials; in each, two tasks (each in `unboxed_run`) run at
once: alice transfers 1 unit `r1 → r2` (`action_id: "transfer"`,
`provider_id: org.id`, `receiver_id: org.id`,
`resource_inventoried_as_id: r1`, `to_resource_inventoried_as_id: r2`) and
`r2 → r1`. Rescue exceptions into `{:raised, e}`; assert neither result is
`{:raised, %Postgrex.Error{postgres: %{code: :deadlock_detected}}}` and each
is `{:ok, _}` or a ValueFlows `{:error, binary}`.

Test B — "event waiting on a revoke of the signer's admin role is
denied": task A (bob) in `Repo.transaction` revokes alice's admin
relationship via `AgentRelationship.Domain.delete(ctx(bob), alice_rel.id)`,
sends `:locked`, waits for `:commit`; after `:locked`, task B (alice) emits
`lower` 1 unit on `r1` with provider = receiver = org; assert
`Task.yield(b, 300) == nil`; in `try/after` always send `:commit`; then
A → `{:ok, _}`, B → `{:error, :forbidden}`.

- [ ] **Step 2: Run several times**

Run: `for i in 1 2 3; do ./mann test test/authz/concurrency_events.test.exs || break; done`
Expected: 2 tests, 0 failures, three times.

- [ ] **Step 3: Prove Test A bites** — temporarily remove `order_by: r.id`
from `lock_resources/2` in `event_facts.ex` *and* load the two resources
with two separate queries in request order; run Test A; record whether it
raises 40P01 (it may not, because `handle_insert` also locks); restore the
file exactly (`git diff --quiet src/zenflows/authz/event_facts.ex`).
Report the result either way.

- [ ] **Step 4: Commit**

```bash
git add test/authz/concurrency_events.test.exs
git commit -m "test(authz): event concurrency against opposite transfers and revokes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Docs and final verification

**Files:**
- Modify: `docs/authz-events-design.md` (status, deltas section)
- Modify: `docs/authz-release-notes.md`
- Modify: `docs/configuration-guide.md`, `conf/.env.templ`

- [ ] **Step 1: Configuration docs** — `docs/configuration-guide.md`:

```markdown
* `AUTHZ_CLAIMABLE_AGENTS`: Comma-separated agent ids whose resources any
  signed person may claim into a new resource of their own (for example the
  LOSH import agent).  The default is empty.  The server refuses to start if
  an entry is not a valid id.
```

`conf/.env.templ`, in the `## authz` block: `#export AUTHZ_CLAIMABLE_AGENTS=`.

- [ ] **Step 2: Release notes** — `docs/authz-release-notes.md`: change the
status line to "CRUD and events enforced; processes, intents and proposals
pending"; add a section "Event authorization (slice 2)":

```markdown
## Event authorization (slice 2)

- `createEconomicEvent`: the signer must act for the provider or the
  receiver (themselves, or an organization they administer), and must
  control every resource the event changes (including a container's
  contents).  `cite` and `use` may reference any resource.  `combine` and
  `separate` are rejected.
- Resources created by `transfer`, `transferAllRights`, `transferCustody`
  and `move` are controlled by the receiver.
- Claims: resources controlled by an agent in `AUTHZ_CLAIMABLE_AGENTS` may
  be transferred by anyone into a new resource of their own; each claim is
  logged as `resource.claim`.  **Set `AUTHZ_CLAIMABLE_AGENTS` to the LOSH
  agent id before deploying, or the GUI claim page stops working.**
- `updateEconomicEvent` works again (the resolver argument was broken) and
  is limited to the event's provider or receiver.
- Still unauthorized: processes, process groups, intents, proposals,
  proposed intents, satisfactions, agreements; attaching an event to
  another agent's process is still possible.
```

Update "Known limitations" accordingly (remove the statement that events
are unauthorized).

- [ ] **Step 3: Spec** — `docs/authz-events-design.md`: status
`Implemented on feat/authz-events`; add `## 12. Deltas from the original
draft` with the four plan deltas verbatim plus any implementation rulings
recorded during execution.

- [ ] **Step 4: Final verification**

Run: `./mann mix compile --force 2>&1 | grep -i warning`
Expected: only the pre-existing Jason.Encoder redefinition warning.

Run: `./mann test`
Expected: only the 7 known failures; every `test/authz/*` test passes.

- [ ] **Step 5: Commit**

```bash
git add docs/authz-events-design.md docs/authz-release-notes.md docs/configuration-guide.md
git add -f conf/.env.templ
git commit -m "docs(authz): event authorization release notes and configuration" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
