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

# Processes, intents and proposals (RBAC slice 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Processes, proposals and intents get a controller; the 14
mutations of this family and the attachment of events/intents to processes
are decided by the slice-1/2 authorization machinery.

**Architecture:** A generic `zf_object_control` table with
`ObjectControl`/`ObjectControl.Domain` (mirroring `ResourceControl`), new
`Facts` loaders and `Policy` clauses, enforced inside each domain's
`Ecto.Multi`. `EventFacts`/`EventPolicy` gain the process rule.

**Tech Stack:** Elixir 1.14, Ecto SQL + PostgreSQL, Absinthe 1.7.1, ExUnit.

**Spec:** `docs/authz-processes-design.md`. Earlier slices:
`docs/authz-foundation-design.md`, `docs/authz-events-design.md`.

## Spec deltas (decided while planning — fold into the spec in Task 8)

1. Telemetry rules `:control`/`:party` are not added: object actions go
   through `Policy` clauses that return `{:error, :forbidden}` (rule `nil`),
   as in slice 1. Only events gain the `:process` rule.
2. Anonymous calls under `allow_unchecked` create processes, proposals and
   intents **without** a control row (there is no agent to make
   controller); in production anonymous creates are `UNAUTHENTICATED`.
3. `Process.Domain` write functions are rewritten from the functional
   `Repo.multi(fn -> ... end)` style into `Ecto.Multi` with authorize steps;
   the "a ProcessGroup must not group other ProcessGroups" check is kept.

## Global Constraints

- Tabs, unindented top-level module code, trailing commas; AGPL SPDX header
  on every new file (copy lines 1-17 of `src/zenflows/authz/policy.ex`;
  migrations use the same `#` header; docs the HTML-comment header).
- `zf_object_control.target_type` values: exactly `"process"`,
  `"proposal"`, `"intent"`. `source` values: `"creation"`, `"admin"`.
- New Policy actions: exactly `process.create process.update
  process.delete proposal.create proposal.update proposal.delete
  intent.create intent.update intent.delete proposed_intent.create
  proposed_intent.delete satisfaction.create satisfaction.update
  satisfaction.delete object_control.assign`.
- Service action sets: `:import` and `:migration` gain `process.create
  intent.create proposal.create`; `:admin_key` gains `object_control.assign`.
- New log actions: `object_control.set`, `object_control.remove`; new log
  `after`/`before` key: `target_type`.
- Lock order: resource rows → resource control → object control (`FOR
  SHARE` in decisions; `FOR UPDATE` only by the object's own
  update/delete/assign) → admin rows (`FOR SHARE`).
- Baseline: 736 tests, 7 known failures (`test/restroom.test.exs:25,35,41`,
  `test/vf/economic_resource/domain.test.exs:81`,
  `test/vf/person/type.test.exs:94,155`,
  `test/authz/organization.test.exs:79`). Never add failures.
- Stage files explicitly; migrations with `git add -f`. Commit trailer
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Never import `Ecto.Query` into a VF domain module that defines
  `update/3` (call ambiguity); use `require Ecto.Query` +
  `Ecto.Query.from/2`.

## Review Focus

1. **`finished`-only path** — an `updateIntent` that sets `finished: true`
   plus any other field must not use the same-proposal rule. Pinned in Task 4.
2. **Orphan control rows** — every delete path of a process, proposal or
   intent removes its control row; anonymous-unchecked deletes too. Pinned
   in Task 7 guard.
3. **Intent with both inputOf and outputOf** — both processes must be
   controlled. Pinned in Task 2 unit test.
4. **Satisfaction by commitment** — `satisfiedByCommitment` without an event
   is denied for persons. Pinned in Task 2/5.
5. **Slice-2 tests on factory processes** — tests that attach a Person's
   event to `Factory.insert!(:process)` must switch to
   `Factory.insert_process!/1` or they fail with FORBIDDEN. Pinned in Task 6.

---

### Task 1: Object control table and domain

**Files:**
- Create: `priv/repo/migrations/20261003100000_create_zf_object_control.exs`
- Create: `src/zenflows/authz/object_control.ex`
- Create: `src/zenflows/authz/object_control/domain.ex`
- Test: `test/authz/object_control.test.exs`

**Interfaces:**
- Produces:
  - schema `Zenflows.Authz.ObjectControl` (`target_type :: String.t()`, `target_id`, `controller_id`, `source :: :creation | :admin`, `epoch`), `changeset/1,2`
  - `ObjectControl.Domain.one(repo \\ Repo, type, id) :: {:ok, t} | {:error, "not found"}`
  - `ObjectControl.Domain.multi_on_create(multi, ctx, type, key) :: Multi.t()` — Person principal only: inserts a row for `changes[key].id` and logs `object_control.set`; no-op for services and anonymous
  - `ObjectControl.Domain.multi_remove(multi, ctx, type, id) :: Multi.t()` — deletes the row if present and logs `object_control.remove`
  - `ObjectControl.Domain.assign(ctx, type, id, person_id, reason) :: {:ok, t} | {:error, term}`

- [ ] **Step 1: Write the failing test** — `test/authz/object_control.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.ObjectControl do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.Multi
alias Zenflows.Authz.{ExecutionContext, ObjectControl, PermissionLog}

defp admin_ctx(),
	do: ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})

setup do
	%{alice: Factory.insert!(:person), proc: Factory.insert!(:process)}
end

test "multi_on_create records the person as controller and logs it", c do
	{:ok, %{"p.control" => control}} =
		Multi.new()
		|> Multi.put("p", c.proc)
		|> ObjectControl.Domain.multi_on_create(Factory.ctx(c.alice), "process", "p")
		|> Repo.transaction()
	assert %ObjectControl{target_type: "process", source: :creation, controller_id: cid} = control
	assert cid == c.alice.id
	proc_id = c.proc.id
	assert [%PermissionLog{action: "object_control.set", target_type: "process", target_id: ^proc_id}] =
		Repo.all(from l in PermissionLog, where: l.target_id == ^proc_id)
end

test "multi_on_create is a no-op for anonymous and services", c do
	for ctx <- [Factory.ctx(), ExecutionContext.service(:import, nil)] do
		{:ok, _} =
			Multi.new()
			|> Multi.put("p", c.proc)
			|> ObjectControl.Domain.multi_on_create(ctx, "process", "p")
			|> Repo.transaction()
	end
	assert {:error, "not found"} = ObjectControl.Domain.one("process", c.proc.id)
end

test "multi_remove deletes the row and logs; absent row is fine", c do
	{:ok, _} = ObjectControl.Domain.assign(admin_ctx(), "process", c.proc.id, c.alice.id, "ticket")
	{:ok, _} = Multi.new() |> ObjectControl.Domain.multi_remove(Factory.ctx(c.alice), "process", c.proc.id) |> Repo.transaction()
	assert {:error, "not found"} = ObjectControl.Domain.one("process", c.proc.id)
	assert {:ok, _} = Multi.new() |> ObjectControl.Domain.multi_remove(Factory.ctx(c.alice), "process", c.proc.id) |> Repo.transaction()
	proc_id = c.proc.id
	assert ["object_control.remove", "object_control.set"] ==
		Repo.all(from l in PermissionLog, where: l.target_id == ^proc_id, select: l.action) |> Enum.sort()
end

test "assign: admin key only, reason required, replaces and bumps epoch", c do
	bob = Factory.insert!(:person)
	assert {:error, :forbidden} = ObjectControl.Domain.assign(Factory.ctx(c.alice), "process", c.proc.id, c.alice.id, "x")
	assert {:error, "reason is required"} = ObjectControl.Domain.assign(admin_ctx(), "process", c.proc.id, c.alice.id, " ")
	assert {:ok, %ObjectControl{epoch: 0, source: :admin}} =
		ObjectControl.Domain.assign(admin_ctx(), "process", c.proc.id, c.alice.id, "first")
	assert {:ok, %ObjectControl{epoch: 1, controller_id: cid}} =
		ObjectControl.Domain.assign(admin_ctx(), "process", c.proc.id, bob.id, "second")
	assert cid == bob.id
	assert {:error, _} = ObjectControl.Domain.assign(admin_ctx(), "planet", c.proc.id, bob.id, "x")
end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `./mann test test/authz/object_control.test.exs`
Expected: compile error, `Zenflows.Authz.ObjectControl` not available.

- [ ] **Step 3: Migration**

```elixir
defmodule Zenflows.DB.Repo.Migrations.Create_zf_object_control do
use Ecto.Migration

def change() do
	create table("zf_object_control", primary_key: false) do
		add :target_type, :string, null: false, primary_key: true
		add :target_id, :binary_id, null: false, primary_key: true
		add :controller_id, references("vf_agent"), null: false
		add :source, :string, null: false
		add :epoch, :integer, null: false, default: 0
		timestamps()
	end
	create index("zf_object_control", [:controller_id])
	create constraint("zf_object_control", :target_type_check,
		check: "target_type IN ('process', 'proposal', 'intent')")
	create constraint("zf_object_control", :source_check,
		check: "source IN ('creation', 'admin')")
end
end
```

- [ ] **Step 4: Schema** — `src/zenflows/authz/object_control.ex`:

```elixir
defmodule Zenflows.Authz.ObjectControl do
@moduledoc """
Administrative control of a process, proposal or intent.  One row per
object; `target_id` has no foreign key (it points at three tables), so
deletes remove the row explicitly (`ObjectControl.Domain.multi_remove/4`).
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema
alias Zenflows.VF.Agent

@types ~w[process proposal intent]

@type t() :: %__MODULE__{}

@primary_key false
schema "zf_object_control" do
	field :target_type, :string, primary_key: true
	field :target_id, Zenflows.DB.ID, primary_key: true
	belongs_to :controller, Agent
	field :source, Ecto.Enum, values: [:creation, :admin]
	field :epoch, :integer, default: 0
	timestamps()
end

@spec types() :: [String.t()]
def types(), do: @types

@reqr ~w[target_type target_id controller_id source]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @reqr ++ [:epoch])
	|> Changeset.validate_required(@reqr)
	|> Changeset.validate_inclusion(:target_type, @types)
	|> Changeset.assoc_constraint(:controller)
end
end
```

- [ ] **Step 5: Domain** — `src/zenflows/authz/object_control/domain.ex`:

```elixir
defmodule Zenflows.Authz.ObjectControl.Domain do
@moduledoc "Reads and writes of object control (processes, proposals, intents)."

require Ecto.Query

alias Ecto.Multi
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, Log, ObjectControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.Person

@spec one(Ecto.Repo.t(), String.t(), String.t()) :: {:ok, ObjectControl.t()} | {:error, String.t()}
def one(repo \\ Repo, type, id) do
	case repo.get_by(ObjectControl, target_type: type, target_id: id) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@doc """
Record the acting Person as controller of the object stored under `key`.
Services and anonymous calls create objects without a control row.
"""
@spec multi_on_create(Multi.t(), ExecutionContext.t(), String.t(), term()) :: Multi.t()
def multi_on_create(m, %ExecutionContext{principal: %Person{id: pid}} = ctx, type, key) do
	m
	|> Multi.run("#{key}.control", fn repo, changes ->
		%{target_type: type, target_id: Map.fetch!(changes, key).id,
			controller_id: pid, source: :creation}
		|> ObjectControl.changeset()
		|> repo.insert()
	end)
	|> Log.multi_insert("#{key}.control.log", ctx, fn changes ->
		c = Map.fetch!(changes, "#{key}.control")
		%{action: "object_control.set", target_type: type, target_id: c.target_id,
			subject_id: c.controller_id,
			after: %{controller_id: c.controller_id, source: c.source, target_type: type}}
	end)
end
def multi_on_create(m, _ctx, _type, _key), do: m

@doc "Remove the control row of a deleted object (if any) and log it."
@spec multi_remove(Multi.t(), ExecutionContext.t(), String.t(), String.t()) :: Multi.t()
def multi_remove(m, ctx, type, id) do
	key = "object_control.remove.#{type}.#{id}"
	m
	|> Multi.run(key, fn repo, _ ->
		case one(repo, type, id) do
			{:ok, c} -> with {:ok, _} <- repo.delete(c), do: {:ok, c}
			{:error, _} -> {:ok, nil}
		end
	end)
	|> Log.multi_insert("#{key}.log", ctx, fn changes ->
		case Map.fetch!(changes, key) do
			nil -> nil
			c -> %{action: "object_control.remove", target_type: type, target_id: id,
				subject_id: c.controller_id,
				before: %{controller_id: c.controller_id, source: c.source,
					epoch: c.epoch, target_type: type}}
		end
	end)
end

@doc "Admin key only: create or replace the controller, with a logged reason."
@spec assign(ExecutionContext.t(), String.t(), String.t(), String.t(), String.t())
	:: {:ok, ObjectControl.t()} | {:error, term()}
def assign(ctx, type, id, person_id, reason) do
	Multi.new()
	|> Multi.run(:authz, fn _, _ ->
		with :ok <- Authz.authorize(ctx, "object_control.assign", %Facts{}), do: {:ok, nil}
	end)
	|> Multi.run(:checks, fn repo, _ ->
		cond do
			type not in ObjectControl.types() -> {:error, "unknown target type"}
			not (is_binary(reason) and String.trim(reason) != "") -> {:error, "reason is required"}
			not repo.exists?(Ecto.Query.from(p in Person, where: p.id == ^person_id and p.type == :per)) ->
				{:error, "person not found"}
			true -> {:ok, nil}
		end
	end)
	|> Multi.run(:control, fn repo, _ ->
		case repo.one(Ecto.Query.from(c in ObjectControl,
				where: c.target_type == ^type and c.target_id == ^id, lock: "FOR UPDATE")) do
			nil ->
				%{target_type: type, target_id: id, controller_id: person_id, source: :admin}
				|> ObjectControl.changeset()
				|> repo.insert()
			c ->
				c
				|> ObjectControl.changeset(%{controller_id: person_id, source: :admin, epoch: c.epoch + 1})
				|> repo.update()
		end
	end)
	|> Log.multi_insert(:log, ctx, fn %{control: c} ->
		%{action: "object_control.set", target_type: type, target_id: id,
			subject_id: c.controller_id, reason: reason,
			after: %{controller_id: c.controller_id, source: c.source, target_type: type}}
	end)
	|> Repo.transaction()
	|> case do
		{:ok, %{control: c}} -> {:ok, c}
		{:error, _, reason, _} -> {:error, reason}
	end
end
end
```

Also add `object_control.assign` to `@actions` in `src/zenflows/authz/policy.ex`
and to the `:admin_key` set in `src/zenflows/authz/execution_context.ex`
(the full list of new actions lands in Task 2; adding this one now lets
`assign/5` work). `Factory.insert!(:process)` must not create control rows
(it uses a raw insert — keep it that way).

Note: `assign/5` validates `target_type` but does not check that the
target object exists (polymorphic); document that in the `@doc`.

- [ ] **Step 6: Run tests, then full suite**

Run: `./mann test test/authz/object_control.test.exs` → all pass.
Run: `./mann test` → only the 7 known failures (the log-content test may
need `target_type` in `@allowed_keys` only once Task 3 creates rows through
domains; it is not exercised yet).

- [ ] **Step 7: Commit**

```bash
git add -f priv/repo/migrations/20261003100000_create_zf_object_control.exs
git add src/zenflows/authz/object_control.ex src/zenflows/authz/object_control/domain.ex src/zenflows/authz/policy.ex src/zenflows/authz/execution_context.ex test/authz/object_control.test.exs
git commit -m "feat(authz): object control for processes, proposals and intents" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Policy clauses and facts loaders

**Files:**
- Modify: `src/zenflows/authz/facts.ex` (struct fields, loaders)
- Modify: `src/zenflows/authz/policy.ex` (actions, clauses)
- Modify: `src/zenflows/authz/execution_context.ex` (service sets)
- Test: `test/authz/object_policy.test.exs`, `test/authz/object_facts.test.exs`

**Interfaces:**
- Consumes: `ObjectControl` (Task 1).
- Produces:
  - `%Facts{}` new fields (defaults): `process_controls: %{}`, `intent: nil`, `intent_control: nil`, `event: nil`, `sibling_parties: MapSet.new()`, `finished_only: false`. Existing `control` holds the target's `ObjectControl` (or the proposal's, for proposed intents).
  - Loaders (all `:: Facts.t()`):
    - `Facts.for_object(repo, ctx, type, id)` — target (`Process`/`Proposal`/`Intent` by type) `FOR UPDATE`, control `FOR UPDATE`, `admin_of [controller]`
    - `Facts.for_intent_create(repo, ctx, changes)` — `target: changes`, process controls of `input_of_id`/`output_of_id` `FOR SHARE`, `admin_of [provider, receiver | process controllers]`
    - `Facts.for_intent_update(repo, ctx, id, params)` — target intent `FOR UPDATE`, its control `FOR UPDATE`, `sibling_parties` (providers/receivers of intents published in the same proposals, unlocked), `finished_only` (params, minus `:id`, are exactly `%{finished: true}`), `admin_of [controller, provider, receiver | siblings]`
    - `Facts.for_proposed_intent_create(repo, ctx, proposal_id, intent_id)` — `control`: proposal control `FOR SHARE`; `intent`; `intent_control`; `admin_of [proposal controller, intent controller, intent provider, intent receiver]`
    - `Facts.for_proposed_intent(repo, ctx, id)` — `target` proposed intent `FOR UPDATE`, `control`: its proposal's control `FOR SHARE`, `admin_of [controller]`
    - `Facts.for_satisfaction_create(repo, ctx, changes)` — `target: changes`, `event` (by `satisfied_by_event_id`, or nil), `intent` (by `satisfies_id`), `admin_of [event provider, event receiver]`
    - `Facts.for_satisfaction(repo, ctx, id)` — `target` satisfaction `FOR UPDATE`, its `event`, `admin_of [event provider, event receiver]`

- [ ] **Step 1: Write the failing unit tests** — `test/authz/object_policy.test.exs`
(pure; `use ExUnit.Case, async: true`; opts `@strict [enforce: true, allow_unchecked: false]`;
contexts via `ExecutionContext.from_resolution(%{context: %{req_user: %Person{id: id}}})`):

```elixir
defmodule ZenflowsTest.Authz.ObjectPolicy do
use ExUnit.Case, async: true

alias Zenflows.Authz.{ExecutionContext, Facts, ObjectControl, Policy}
alias Zenflows.DB.ID
alias Zenflows.VF.{EconomicEvent, Intent, Person, ProposedIntent, Satisfaction}

@strict [enforce: true, allow_unchecked: false]

setup do
	a = ID.gen(); b = ID.gen(); org = ID.gen(); p1 = ID.gen(); p2 = ID.gen()
	%{a: a, b: b, org: org, p1: p1, p2: p2,
		as_a: ExecutionContext.from_resolution(%{context: %{req_user: %Person{id: a}}}),
		as_b: ExecutionContext.from_resolution(%{context: %{req_user: %Person{id: b}}})}
end

defp ctl(id, type \\ "process"), do: %ObjectControl{target_type: type, target_id: ID.gen(), controller_id: id}
defp auth(ctx, action, f), do: Policy.authorize(ctx, action, f, @strict)

test "create of process/proposal: any person", c do
	for a <- ~w[process.create proposal.create], do: assert :ok = auth(c.as_b, a, %Facts{})
end

test "update/delete of process/proposal/intent: controller or admin of controlling org", c do
	for a <- ~w[process.update process.delete proposal.update proposal.delete intent.delete] do
		assert :ok = auth(c.as_a, a, %Facts{control: ctl(c.a)})
		assert {:error, :forbidden} = auth(c.as_b, a, %Facts{control: ctl(c.a)})
		assert :ok = auth(c.as_b, a, %Facts{control: ctl(c.org), admin_of: MapSet.new([c.org])})
		assert {:error, :forbidden} = auth(c.as_a, a, %Facts{control: nil})
	end
end

describe "intent.create" do
	test "without process: signer must act for provider or receiver", c do
		assert :ok = auth(c.as_a, "intent.create", %Facts{target: %{provider_id: c.a}})
		assert :ok = auth(c.as_a, "intent.create", %Facts{target: %{receiver_id: c.a}})
		assert {:error, :forbidden} = auth(c.as_b, "intent.create", %Facts{target: %{receiver_id: c.a}})
	end

	test "with process: signer must control it, and may then name only the other side", c do
		f = %Facts{target: %{input_of_id: c.p1, receiver_id: c.a}, process_controls: %{c.p1 => ctl(c.b)}}
		assert :ok = auth(c.as_b, "intent.create", f)
		assert {:error, :forbidden} = auth(c.as_a, "intent.create", f)
		assert {:error, :forbidden} =
			auth(c.as_b, "intent.create", %{f | process_controls: %{}})
	end

	test "with both processes: both must be controlled", c do
		f = %Facts{target: %{input_of_id: c.p1, output_of_id: c.p2, provider_id: c.b},
			process_controls: %{c.p1 => ctl(c.b), c.p2 => ctl(c.a)}}
		assert {:error, :forbidden} = auth(c.as_b, "intent.create", f)
	end
end

describe "intent.update" do
	test "controller, named party, or finished-only via same proposal", c do
		int = %Intent{provider_id: c.a, receiver_id: nil}
		assert :ok = auth(c.as_a, "intent.update", %Facts{target: int})
		assert :ok = auth(c.as_b, "intent.update", %Facts{target: int, control: ctl(c.b, "intent")})
		assert {:error, :forbidden} = auth(c.as_b, "intent.update", %Facts{target: int})
		sib = %Facts{target: int, sibling_parties: MapSet.new([c.b]), finished_only: true}
		assert :ok = auth(c.as_b, "intent.update", sib)
		assert {:error, :forbidden} = auth(c.as_b, "intent.update", %{sib | finished_only: false})
	end
end

describe "proposed_intent" do
	test "create: control proposal and (control intent or party)", c do
		int = %Intent{provider_id: c.a}
		f = %Facts{control: ctl(c.a, "proposal"), intent: int}
		assert :ok = auth(c.as_a, "proposed_intent.create", f)
		assert {:error, :forbidden} = auth(c.as_b, "proposed_intent.create", f)
		assert {:error, :forbidden} =
			auth(c.as_b, "proposed_intent.create", %{f | control: ctl(c.b, "proposal")})
		assert :ok = auth(c.as_b, "proposed_intent.create",
			%{f | control: ctl(c.b, "proposal"), intent_control: ctl(c.b, "intent")})
	end

	test "delete: control the proposal", c do
		f = %Facts{target: %ProposedIntent{}, control: ctl(c.a, "proposal")}
		assert :ok = auth(c.as_a, "proposed_intent.delete", f)
		assert {:error, :forbidden} = auth(c.as_b, "proposed_intent.delete", f)
	end
end

describe "satisfaction" do
	test "create: party of the event, and event shares an agent with the intent", c do
		evt = %EconomicEvent{provider_id: c.b, receiver_id: c.a}
		assert :ok = auth(c.as_a, "satisfaction.create",
			%Facts{event: evt, intent: %Intent{provider_id: c.b}})
		assert {:error, :forbidden} = auth(c.as_a, "satisfaction.create",
			%Facts{event: evt, intent: %Intent{provider_id: c.org}})
		assert {:error, :forbidden} = auth(c.as_b, "satisfaction.create",
			%Facts{event: %EconomicEvent{provider_id: c.a, receiver_id: c.a}, intent: %Intent{provider_id: c.a}})
		assert {:error, :forbidden} = auth(c.as_a, "satisfaction.create",
			%Facts{event: nil, intent: %Intent{provider_id: c.a}})
	end

	test "update/delete: party of the satisfying event", c do
		for a <- ~w[satisfaction.update satisfaction.delete] do
			f = %Facts{target: %Satisfaction{}, event: %EconomicEvent{provider_id: c.a, receiver_id: c.a}}
			assert :ok = auth(c.as_a, a, f)
			assert {:error, :forbidden} = auth(c.as_b, a, f)
		end
	end
end

test "object_control.assign is admin-key only", c do
	assert {:error, :forbidden} = auth(c.as_a, "object_control.assign", %Facts{})
	admin = ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})
	assert :ok = auth(admin, "object_control.assign", %Facts{})
end

test "services may create processes, proposals and intents" do
	for name <- [:import, :migration], a <- ~w[process.create proposal.create intent.create] do
		assert :ok = Policy.authorize(ExecutionContext.service(name, nil), a, %Facts{}, @strict)
	end
end
end
```

`test/authz/object_facts.test.exs` (`EctoCase, async: true`) must cover, with
real rows:
- `for_object/4` for a process with and without control row (target and
  control loaded; `admin_of` contains the controlling org for an admin);
- `for_intent_create/3` with `input_of_id` → `process_controls` keyed by the
  process id;
- `for_intent_update/4`: an intent published in a proposal with a sibling
  intent whose receiver is Alice → `sibling_parties` contains Alice;
  `finished_only` true for `%{id: x, finished: true}`, false for
  `%{id: x, finished: true, note: "n"}` and for `%{id: x, finished: false}`;
- `for_satisfaction_create/3` loads `event` and `intent`; nil event when
  only `satisfied_by_commitment_id` is given.
(Create intents with `Repo.insert!(Intent.changeset(...))` and proposals /
proposed intents with `Factory.insert!/1`.)

- [ ] **Step 2: Run to verify failure**

Run: `./mann test test/authz/object_policy.test.exs test/authz/object_facts.test.exs`
Expected: failures (unknown actions / undefined loaders).

- [ ] **Step 3: Facts** — in `src/zenflows/authz/facts.ex` add the new
fields to `@type t()` and `defstruct` (defaults above), alias
`Zenflows.Authz.ObjectControl` and `Zenflows.VF.{EconomicEvent, Intent,
Process, Proposal, ProposedIntent, Satisfaction}`, and add:

```elixir
@schemas %{"process" => Process, "proposal" => Proposal, "intent" => Intent}

@spec for_object(Ecto.Repo.t(), ExecutionContext.t(), String.t(), String.t()) :: t()
def for_object(repo, ctx, type, id) do
	schema = Map.fetch!(@schemas, type)
	target = repo.one(from t in schema, where: t.id == ^id, lock: "FOR UPDATE")
	control = lock_object_control(repo, type, id, "FOR UPDATE")
	%__MODULE__{target: target, control: control,
		admin_of: admin_of(repo, ctx, [control && control.controller_id])}
end

@spec for_intent_create(Ecto.Repo.t(), ExecutionContext.t(), map()) :: t()
def for_intent_create(repo, ctx, changes) do
	ids = Enum.reject([Map.get(changes, :input_of_id), Map.get(changes, :output_of_id)], &is_nil/1)
	controls = lock_object_controls(repo, "process", ids)
	%__MODULE__{target: changes, process_controls: controls,
		admin_of: admin_of(repo, ctx,
			[Map.get(changes, :provider_id), Map.get(changes, :receiver_id)
				| Enum.map(Map.values(controls), & &1.controller_id)])}
end

@spec for_intent_update(Ecto.Repo.t(), ExecutionContext.t(), String.t(), map()) :: t()
def for_intent_update(repo, ctx, id, params) do
	target = repo.one(from i in Intent, where: i.id == ^id, lock: "FOR UPDATE")
	control = lock_object_control(repo, "intent", id, "FOR UPDATE")
	siblings = sibling_parties(repo, id)
	ids = [control && control.controller_id,
		target && target.provider_id, target && target.receiver_id | MapSet.to_list(siblings)]
	%__MODULE__{target: target, control: control, sibling_parties: siblings,
		finished_only: Map.drop(params, [:id, "id"]) in [%{finished: true}, %{"finished" => true}],
		admin_of: admin_of(repo, ctx, ids)}
end

@spec for_proposed_intent_create(Ecto.Repo.t(), ExecutionContext.t(), String.t(), String.t()) :: t()
def for_proposed_intent_create(repo, ctx, proposal_id, intent_id) do
	control = lock_object_control(repo, "proposal", proposal_id, "FOR SHARE")
	intent = repo.get(Intent, intent_id)
	intent_control = lock_object_control(repo, "intent", intent_id, "FOR SHARE")
	%__MODULE__{control: control, intent: intent, intent_control: intent_control,
		admin_of: admin_of(repo, ctx, [control && control.controller_id,
			intent_control && intent_control.controller_id,
			intent && intent.provider_id, intent && intent.receiver_id])}
end

@spec for_proposed_intent(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_proposed_intent(repo, ctx, id) do
	target = repo.one(from p in ProposedIntent, where: p.id == ^id, lock: "FOR UPDATE")
	control = target && lock_object_control(repo, "proposal", target.published_in_id, "FOR SHARE")
	%__MODULE__{target: target, control: control,
		admin_of: admin_of(repo, ctx, [control && control.controller_id])}
end

@spec for_satisfaction_create(Ecto.Repo.t(), ExecutionContext.t(), map()) :: t()
def for_satisfaction_create(repo, ctx, changes) do
	event = case Map.get(changes, :satisfied_by_event_id) do
		nil -> nil
		eid -> repo.get(EconomicEvent, eid)
	end
	intent = case Map.get(changes, :satisfies_id) do
		nil -> nil
		iid -> repo.get(Intent, iid)
	end
	%__MODULE__{target: changes, event: event, intent: intent,
		admin_of: admin_of(repo, ctx, [event && event.provider_id, event && event.receiver_id])}
end

@spec for_satisfaction(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_satisfaction(repo, ctx, id) do
	target = repo.one(from s in Satisfaction, where: s.id == ^id, lock: "FOR UPDATE")
	event = target && target.satisfied_by_event_id && repo.get(EconomicEvent, target.satisfied_by_event_id)
	%__MODULE__{target: target, event: event,
		admin_of: admin_of(repo, ctx, [event && event.provider_id, event && event.receiver_id])}
end

defp lock_object_control(repo, type, id, lock) do
	from(c in ObjectControl, where: c.target_type == ^type and c.target_id == ^id, lock: ^lock)
	|> repo.one()
end

defp lock_object_controls(_repo, _type, []), do: %{}
defp lock_object_controls(repo, type, ids) do
	from(c in ObjectControl, where: c.target_type == ^type and c.target_id in ^ids,
		order_by: c.target_id, lock: "FOR SHARE")
	|> repo.all()
	|> Map.new(&{&1.target_id, &1})
end

defp sibling_parties(repo, intent_id) do
	from(pi in ProposedIntent,
		join: sib in ProposedIntent, on: sib.published_in_id == pi.published_in_id,
		join: i in Intent, on: i.id == sib.publishes_id,
		where: pi.publishes_id == ^intent_id,
		select: [i.provider_id, i.receiver_id])
	|> repo.all()
	|> List.flatten()
	|> Enum.reject(&is_nil/1)
	|> MapSet.new()
end
```

(Ecto `lock:` accepts a literal string only; if `lock: ^lock` does not
compile, write two private functions `lock_object_control_update/3` and
`lock_object_control_share/3` with literal locks.)

- [ ] **Step 4: Policy and service sets** — add the 15 actions to
`@actions` (`object_control.assign` is already there from Task 1); in
`execution_context.ex` add `process.create intent.create proposal.create`
to `:import` and `:migration`. Add before the final
`defp person_may?(_pid, _action, _facts), do: false` clause:

```elixir
defp person_may?(_pid, action, _f) when action in ~w[process.create proposal.create],
	do: true
defp person_may?(pid, action, %Facts{control: %ObjectControl{} = c} = f)
		when action in ~w[process.update process.delete proposal.update proposal.delete intent.delete],
	do: controls?(pid, f, c)
defp person_may?(pid, "intent.create", %Facts{target: %{} = t} = f) do
	case Enum.reject([Map.get(t, :input_of_id), Map.get(t, :output_of_id)], &is_nil/1) do
		[] -> acts_for?(pid, f, Map.get(t, :provider_id)) or acts_for?(pid, f, Map.get(t, :receiver_id))
		ids -> Enum.all?(ids, &controls?(pid, f, Map.get(f.process_controls, &1)))
	end
end
defp person_may?(pid, "intent.update", %Facts{target: %Intent{} = i} = f) do
	controls?(pid, f, f.control)
		or acts_for?(pid, f, i.provider_id) or acts_for?(pid, f, i.receiver_id)
		or (f.finished_only and Enum.any?(f.sibling_parties, &acts_for?(pid, f, &1)))
end
defp person_may?(pid, "proposed_intent.create", %Facts{intent: %Intent{} = i} = f) do
	controls?(pid, f, f.control)
		and (controls?(pid, f, f.intent_control)
			or acts_for?(pid, f, i.provider_id) or acts_for?(pid, f, i.receiver_id))
end
defp person_may?(pid, "proposed_intent.delete", %Facts{target: %ProposedIntent{}} = f),
	do: controls?(pid, f, f.control)
defp person_may?(pid, "satisfaction.create", %Facts{event: %EconomicEvent{} = e, intent: %Intent{} = i} = f) do
	event_agents = Enum.reject([e.provider_id, e.receiver_id], &is_nil/1)
	intent_agents = Enum.reject([i.provider_id, i.receiver_id], &is_nil/1)
	Enum.any?(event_agents, &acts_for?(pid, f, &1))
		and Enum.any?(event_agents, &(&1 in intent_agents))
end
defp person_may?(pid, action, %Facts{event: %EconomicEvent{} = e} = f)
		when action in ~w[satisfaction.update satisfaction.delete],
	do: acts_for?(pid, f, e.provider_id) or acts_for?(pid, f, e.receiver_id)
```

and helpers (if `admin?/2` / `subject_ok?/3` already exist, reuse them):

```elixir
defp acts_for?(_pid, _f, nil), do: false
defp acts_for?(pid, f, id), do: id == pid or MapSet.member?(f.admin_of, id)

defp controls?(_pid, _f, nil), do: false
defp controls?(pid, f, %{controller_id: cid}), do: acts_for?(pid, f, cid)
```

Alias `Zenflows.Authz.ObjectControl` and `Zenflows.VF.{EconomicEvent,
Intent, ProposedIntent}` in `policy.ex`; update the `@moduledoc`.

- [ ] **Step 5: Run tests**

Run: `./mann test test/authz/`
Expected: all pass except the known `organization.test.exs:79`.

- [ ] **Step 6: Commit**

```bash
git add src/zenflows/authz/facts.ex src/zenflows/authz/policy.ex src/zenflows/authz/execution_context.ex test/authz/object_policy.test.exs test/authz/object_facts.test.exs
git commit -m "feat(authz): policy and facts for processes, proposals, intents, satisfactions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Processes and proposals; objectControl API

**Files:**
- Modify: `src/zenflows/vf/process/domain.ex`, `resolv.ex`, `type.ex`
- Modify: `src/zenflows/vf/proposal/domain.ex`, `resolv.ex`, `type.ex`
- Modify: `src/zenflows/authz/type.ex`, `src/zenflows/authz/resolv.ex`, `src/zenflows/gql/schema.ex` (if needed)
- Modify: `test/help/factory.ex` (`insert_process!/1`, `insert_proposal!/1`)
- Modify (call sites): `test/vf/process/domain.test.exs`, `test/vf/proposal/domain.test.exs`, `test/vf/economic_resource/track_and_trace.test.exs`, any other caller found by `grep -rn "Process.Domain.\(create\|update\|delete\)\|Proposal.Domain.\(create\|update\|delete\)" src test priv`
- Modify: `test/authz/log_content.test.exs` (`@allowed_keys` gains `target_type`)
- Test: `test/authz/processes.test.exs`

**Interfaces:**
- Produces: `Process.Domain.create(ctx, params)`, `update(ctx, id, params)`, `delete(ctx, id)` (+ bangs), same for `Proposal.Domain`; `Factory.insert_process!(person) :: Process.t()`, `Factory.insert_proposal!(person) :: Proposal.t()`; GraphQL `objectControl(targetType, targetId)`, `assignObjectControl(targetType, targetId, personId, reason)`.

- [ ] **Step 1: Write the failing test** — `test/authz/processes.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Processes do
use ZenflowsTest.Help.EctoCase, async: true

import ZenflowsTest.Help.AbsinCase, only: [run!: 2]

alias Zenflows.Authz.{ExecutionContext, ObjectControl}
alias Zenflows.VF.{Process, Proposal}

setup do
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person)}
end

test "creator controls a new process; others cannot update or delete it", c do
	{:ok, proc} = Process.Domain.create(Factory.ctx(c.alice), %{name: "p"})
	assert {:ok, %ObjectControl{controller_id: cid}} = ObjectControl.Domain.one("process", proc.id)
	assert cid == c.alice.id
	assert {:error, :forbidden} = Process.Domain.update(Factory.ctx(c.bob), proc.id, %{name: "x"})
	assert {:error, :forbidden} = Process.Domain.delete(Factory.ctx(c.bob), proc.id)
	assert {:ok, %Process{name: "y"}} = Process.Domain.update(Factory.ctx(c.alice), proc.id, %{name: "y"})
	assert {:ok, _} = Process.Domain.delete(Factory.ctx(c.alice), proc.id)
	assert {:error, "not found"} = ObjectControl.Domain.one("process", proc.id)
end

test "legacy process (no control row) is deny-all until assigned", c do
	proc = Factory.insert!(:process)
	assert {:error, :forbidden} = Process.Domain.update(Factory.ctx(c.alice), proc.id, %{name: "x"})
	admin = ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})
	{:ok, _} = ObjectControl.Domain.assign(admin, "process", proc.id, c.alice.id, "legacy fix")
	assert {:ok, _} = Process.Domain.update(Factory.ctx(c.alice), proc.id, %{name: "x"})
end

test "proposals follow the same rules", c do
	{:ok, prop} = Proposal.Domain.create(Factory.ctx(c.alice), %{name: "sale"})
	assert {:error, :forbidden} = Proposal.Domain.update(Factory.ctx(c.bob), prop.id, %{note: "x"})
	assert {:ok, _} = Proposal.Domain.update(Factory.ctx(c.alice), prop.id, %{note: "y"})
	assert {:error, :forbidden} = Proposal.Domain.delete(Factory.ctx(c.bob), prop.id)
end

test "the ProcessGroup grouping check still applies", c do
	parent = Factory.insert!(:process_group)
	child = Factory.insert!(:process_group)
	Repo.update_all(from(g in Zenflows.VF.ProcessGroup, where: g.id == ^child.id), set: [grouped_in_id: parent.id])
	assert {:error, %Ecto.Changeset{}} =
		Process.Domain.create(Factory.ctx(c.alice), %{name: "p", grouped_in_id: parent.id})
end

test "objectControl query", c do
	{:ok, proc} = Process.Domain.create(Factory.ctx(c.alice), %{name: "p"})
	assert %{data: %{"objectControl" => %{"controller" => %{"id" => id}, "source" => "creation"}}} =
		run!("""
			query ($id: ID!) { objectControl(targetType: "process", targetId: $id) { controller { id } source epoch } }
		""", vars: %{"id" => proc.id})
	assert id == c.alice.id
end
end
```

(If `Factory.insert!(:process_group)` or the grouping check works
differently, adapt only that test to exercise the existing check and say
so in the report.)

- [ ] **Step 2: Run to verify failure**

Run: `./mann test test/authz/processes.test.exs` → failures (arity / no control).

- [ ] **Step 3: Process domain** — in `src/zenflows/vf/process/domain.ex` add
`alias Ecto.Multi`, `alias Zenflows.Authz`,
`alias Zenflows.Authz.{ExecutionContext, Facts, ObjectControl}` and replace
`create/1`, `create!/1`, `update/2`, `update!/2`, `delete/1`, `delete!/1`:

```elixir
@spec create(ExecutionContext.t(), Schema.params()) :: {:ok, Process.t()} | {:error, term()}
def create(%ExecutionContext{} = ctx, params) do
	Multi.new()
	|> Multi.run(:authz, fn _, _ ->
		with :ok <- Authz.authorize(ctx, "process.create", %Facts{}), do: {:ok, nil}
	end)
	|> Multi.insert(:process, fn _ -> check_group(Process.changeset(params)) end)
	|> ObjectControl.Domain.multi_on_create(ctx, "process", :process)
	|> Repo.transaction()
	|> case do
		{:ok, %{process: proc}} -> {:ok, proc}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec create!(ExecutionContext.t(), Schema.params()) :: Process.t()
def create!(ctx, params) do
	{:ok, value} = create(ctx, params)
	value
end

@spec update(ExecutionContext.t(), Schema.id(), Schema.params()) :: {:ok, Process.t()} | {:error, term()}
def update(%ExecutionContext{} = ctx, id, params) do
	Multi.new()
	|> Authz.multi_authorize(:authz, ctx, "process.update",
		fn repo, _ -> Facts.for_object(repo, ctx, "process", id) end)
	|> Authz.multi_target(:one, :authz)
	|> Multi.update(:process, fn %{one: proc} -> check_group(Process.changeset(proc, params)) end)
	|> Repo.transaction()
	|> case do
		{:ok, %{process: proc}} -> {:ok, proc}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec update!(ExecutionContext.t(), Schema.id(), Schema.params()) :: Process.t()
def update!(ctx, id, params) do
	{:ok, value} = __MODULE__.update(ctx, id, params)
	value
end

@spec delete(ExecutionContext.t(), Schema.id()) :: {:ok, Process.t()} | {:error, term()}
def delete(%ExecutionContext{} = ctx, id) do
	Multi.new()
	|> Authz.multi_authorize(:authz, ctx, "process.delete",
		fn repo, _ -> Facts.for_object(repo, ctx, "process", id) end)
	|> Authz.multi_target(:one, :authz)
	|> Multi.delete(:process, fn %{one: proc} -> proc end)
	|> ObjectControl.Domain.multi_remove(ctx, "process", id)
	|> Repo.transaction()
	|> case do
		{:ok, %{process: proc}} -> {:ok, proc}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec delete!(ExecutionContext.t(), Schema.id()) :: Process.t()
def delete!(ctx, id) do
	{:ok, value} = delete(ctx, id)
	value
end

# A ProcessGroup that groups other ProcessGroups cannot group processes.
defp check_group(%{valid?: true, changes: %{grouped_in_id: gid}} = cset) do
	if where(ProcessGroup, grouped_in_id: ^gid) |> Repo.exists?() do
		Changeset.add_error(cset, :grouped_in_id,
			"this ProcessGroup must not group other ProcessGroups")
	else
		cset
	end
end
defp check_group(cset), do: cset
```

(The module already `import`s `Ecto.Query`; `__MODULE__.update` avoids the
ambiguity. If `Multi.insert/3` with a function is not available in this
Ecto version, build the changeset inside `Multi.run` and `repo.insert/1`.)

- [ ] **Step 4: Proposal domain** — same shape: `create(ctx, params)` adds
an authorize step (`proposal.create`, `%Facts{}`) before `multi_insert`
and `ObjectControl.Domain.multi_on_create(ctx, "proposal", key)` after;
`update(ctx, id, params)` / `delete(ctx, id)` use
`Authz.multi_authorize(... "proposal.update"/"proposal.delete", fn repo, _ ->
Facts.for_object(repo, ctx, "proposal", id) end)` +
`Authz.multi_target`, and delete appends
`ObjectControl.Domain.multi_remove(ctx, "proposal", id)`. Keep the
existing `multi_*` helpers used by `create`; remove `multi_one/3` only if
unused.

- [ ] **Step 5: Resolvers, types, API**
- Resolvers pass `ExecutionContext.from_resolution(res)` (process and
  proposal create/update/delete).
- Types: `meta authz: "process.create"` etc. on the six fields.
- `src/zenflows/authz/type.ex`: add object `:object_control`
  (`controller: non_null(:agent)` via `Resolv.controller/3` — reuse it,
  `source: non_null(:string)` via `Resolv.source/3`, `epoch:
  non_null(:integer)`); query field `:object_control` (`meta only_guest?:
  true`, args `target_type: non_null(:string)`, `target_id:
  non_null(:id)`, resolver returns `{:ok, nil}` when not found); mutation
  `:assign_object_control` (`meta only_admin?: true, authz:
  "object_control.assign"`, args `target_type`, `target_id`, `person_id`,
  `reason`, all non-null; returns `non_null(:object_control)`) resolved
  with `ObjectControl.Domain.assign(ExecutionContext.admin_key(res), ...)`.
- `Factory.insert_process!(per)` = `Zenflows.VF.Process.Domain.create!(ctx(per), %{name: str("process")})`;
  `Factory.insert_proposal!(per)` likewise for `Proposal`.
- `test/authz/log_content.test.exs`: add `target_type` to `@allowed_keys`.

- [ ] **Step 6: Call sites**

```bash
sed -i '' -E 's/(^|[^.A-Za-z])Domain\.(create|update|delete)(!?)\(/\1Domain.\2\3(Factory.ctx(), /g' test/vf/process/domain.test.exs test/vf/proposal/domain.test.exs
sed -i '' -E 's/(Process|Proposal)\.Domain\.(create|update|delete)(!?)\(/\1.Domain.\2\3(Factory.ctx(), /g' test/vf/economic_resource/track_and_trace.test.exs
grep -rn "Process.Domain.\(create\|update\|delete\)\|Proposal.Domain.\(create\|update\|delete\)" src test priv | grep -v "ctx"
```

Inspect the diffs (hand-fix any zero-argument piped call the regex
mangles). The final grep must list only lines that already pass a
context.

- [ ] **Step 7: Run tests**

Run: `./mann test test/authz/processes.test.exs test/vf/process test/vf/proposal`
→ all pass. Run: `./mann test` → only the 7 known failures.

- [ ] **Step 8: Commit**

```bash
git add src/zenflows/vf/process src/zenflows/vf/proposal src/zenflows/authz/type.ex src/zenflows/authz/resolv.ex test/help/factory.ex test/authz/processes.test.exs test/authz/log_content.test.exs test/vf/process test/vf/proposal test/vf/economic_resource/track_and_trace.test.exs
git commit -m "feat(authz): control processes and proposals; objectControl API" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Intents

**Files:**
- Modify: `src/zenflows/vf/intent/domain.ex`, `resolv.ex`, `type.ex`
- Modify (call sites): `test/vf/intent/domain.test.exs`, `test/file.test.exs`, and any other caller from `grep -rn "Intent.Domain.\(create\|update\|delete\)" src test priv`
- Test: `test/authz/intents.test.exs`

**Interfaces:**
- Consumes: `Facts.for_intent_create/3`, `Facts.for_intent_update/4`, `Facts.for_object/4`, `ObjectControl.Domain.multi_on_create/4`, `multi_remove/4`, `Factory.insert_process!/1`, `Factory.insert_proposal!/1`.
- Produces: `Intent.Domain.create(ctx, params)`, `update(ctx, id, params)`, `delete(ctx, id)` (+ bangs).

- [ ] **Step 1: Write the failing test** — `test/authz/intents.test.exs` must cover (Alice and Bob persons; `ProposedIntent` rows via `Repo.insert!(ProposedIntent.changeset(%{published_in_id, publishes_id}))`):
  - Bob creates an intent `inputOf` his own process with only `receiver_id: alice` → ok, Bob controls it;
  - Bob creates such an intent `inputOf` Alice's process → `{:error, :forbidden}`;
  - Bob creates a process-less intent with only `receiver_id: alice` → forbidden; with `provider_id: bob` → ok;
  - Alice (named receiver) updates `finished: true` on Bob's intent → ok;
  - the contribution shape: Bob's proposal publishes his `cite` intent (provider Bob only) and an `accept` intent (receiver Alice); Alice updates the `cite` intent with `%{finished: true}` → ok; with `%{finished: true, note: "x"}` → forbidden; Carol (no party anywhere) → forbidden;
  - only the controller deletes: Alice cannot delete Bob's intent, Bob can, and the control row is gone;
  - legacy intent (raw `Repo.insert!`, no control row) with provider Alice: Alice may update it (party), nobody may delete it.

Use a helper that builds valid intent params (copy the minimal valid params
from `test/vf/intent/domain.test.exs` setup: `action_id`, and whatever the
changeset requires).

- [ ] **Step 2: Run to verify failure** — `./mann test test/authz/intents.test.exs`.

- [ ] **Step 3: Domain** — in `src/zenflows/vf/intent/domain.ex` add
`alias Zenflows.Authz`, `alias Zenflows.Authz.{ExecutionContext, Facts, ObjectControl}`;
`create(ctx, params)`:

```elixir
def create(%ExecutionContext{} = ctx, params) do
	key = multi_key()
	cset = Intent.changeset(params)
	Multi.new()
	|> Multi.run("#{key}.authz", fn repo, _ ->
		if cset.valid? do
			facts = Facts.for_intent_create(repo, ctx, cset.changes)
			with :ok <- Authz.authorize(ctx, "intent.create", facts), do: {:ok, facts}
		else
			{:ok, nil}
		end
	end)
	|> Multi.insert(key, cset)
	|> File.Domain.multi_insert(key, :images, :intent_id)
	|> ObjectControl.Domain.multi_on_create(ctx, "intent", key)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end
```

`update(ctx, id, params)` uses
`Authz.multi_authorize("#{key}.authz", ctx, "intent.update", fn repo, _ -> Facts.for_intent_update(repo, ctx, id, params) end)`,
`Authz.multi_target("#{key}.one", "#{key}.authz")`, then the existing update
and file steps. `delete(ctx, id)` uses `"intent.delete"` with
`Facts.for_object(repo, ctx, "intent", id)`, then delete and
`ObjectControl.Domain.multi_remove(ctx, "intent", id)`. Bangs take `ctx`.
The module does not import `Ecto.Query`; keep it that way.

- [ ] **Step 4: Resolvers, types** — pass `ExecutionContext.from_resolution(res)`;
`meta authz: "intent.create"` / `"intent.update"` / `"intent.delete"`.

- [ ] **Step 5: Call sites**

```bash
sed -i '' -E 's/(^|[^.A-Za-z])Domain\.(create|update|delete)(!?)\(/\1Domain.\2\3(Factory.ctx(), /g' test/vf/intent/domain.test.exs
sed -i '' -E 's/Intent\.Domain\.(create|update|delete)(!?)\(/Intent.Domain.\1\2(Factory.ctx(), /g' test/file.test.exs
grep -rn "Intent.Domain.\(create\|update\|delete\)" src test priv | grep -v "ctx"
```

(`ProposedIntent.Domain` lines must not be touched by the second sed —
check `test/file.test.exs` diff.)

- [ ] **Step 6: Run** — `./mann test test/authz/intents.test.exs test/vf/intent`, then `./mann test`.

- [ ] **Step 7: Commit**

```bash
git add src/zenflows/vf/intent test/authz/intents.test.exs test/vf/intent test/file.test.exs
git commit -m "feat(authz): authorize intents" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Proposed intents and satisfactions

**Files:**
- Modify: `src/zenflows/vf/proposed_intent/domain.ex`, `resolv.ex`, `type.ex`
- Modify: `src/zenflows/vf/satisfaction/domain.ex`, `resolv.ex`, `type.ex`
- Modify (call sites): `test/vf/proposed_intent/domain.test.exs`, `test/vf/satisfaction` tests if they call domain write functions (`grep -rn "ProposedIntent.Domain.\(create\|delete\)\|Satisfaction.Domain.\(create\|update\|delete\)\|[^.A-Za-z]Domain.\(create\|update\|delete\)" test/vf/proposed_intent* test/vf/satisfaction*`)
- Test: `test/authz/proposed_intents.test.exs`, `test/authz/satisfactions.test.exs`

**Interfaces:**
- Consumes: `Facts.for_proposed_intent_create/4`, `for_proposed_intent/3`, `for_satisfaction_create/3`, `for_satisfaction/3`.
- Produces: `ProposedIntent.Domain.create(ctx, params)`, `delete(ctx, id)`; `Satisfaction.Domain.create(ctx, params)`, `update(ctx, id, params)`, `delete(ctx, id)` (+ bangs). `ProposedIntent.Domain.update/2` (no GraphQL mutation) is left as is.

- [ ] **Step 1: Failing tests**
  - `proposed_intents.test.exs`: Bob links his own intent to his own proposal → ok; Bob links his intent to Alice's proposal → forbidden; Bob links Alice's intent (Bob not a party, not controller) to Bob's proposal → forbidden; an intent naming Bob as provider but controlled by Alice → ok for Bob on his proposal; only the proposal controller deletes the link.
  - `satisfactions.test.exs`: an event (provider Bob, receiver Alice, created via `EconomicEvent.Domain.create!(Factory.ctx(), ...)` so no authorization is needed for the fixture) satisfying an intent whose provider is Bob → Alice may create the satisfaction; Carol may not; an intent whose parties don't include Bob or Alice → forbidden for Alice; `satisfied_by_commitment_id` only → forbidden (persons); update/delete by a party of the event → ok, by Carol → forbidden.

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Domains** — same shape as Task 4:
  - `ProposedIntent.Domain.create(ctx, params)`: validate changeset; authorize step `"proposed_intent.create"` with `Facts.for_proposed_intent_create(repo, ctx, cset.changes.published_in_id, cset.changes.publishes_id)` when valid (skip for invalid, as in Task 4); then insert.
  - `ProposedIntent.Domain.delete(ctx, id)`: `"proposed_intent.delete"` with `Facts.for_proposed_intent(repo, ctx, id)`, target, delete.
  - `Satisfaction.Domain.create(ctx, params)`: valid changeset → `"satisfaction.create"` with `Facts.for_satisfaction_create(repo, ctx, cset.changes)`.
  - `Satisfaction.Domain.update/delete(ctx, ...)`: `"satisfaction.update"`/`"satisfaction.delete"` with `Facts.for_satisfaction(repo, ctx, id)` + target.

- [ ] **Step 4: Resolvers/types** — contexts from resolution; `meta authz:
  "proposed_intent.create"` on `propose_intent`, `"proposed_intent.delete"`,
  `"satisfaction.create"`, `"satisfaction.update"`, `"satisfaction.delete"`.

- [ ] **Step 5: Call sites** — sed as in Task 4 for each listed test file;
  verify with grep.

- [ ] **Step 6: Run** — new tests, then `./mann test`.

- [ ] **Step 7: Commit**

```bash
git add src/zenflows/vf/proposed_intent src/zenflows/vf/satisfaction test/authz/proposed_intents.test.exs test/authz/satisfactions.test.exs test/vf
git commit -m "feat(authz): authorize proposed intents and satisfactions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Process rule for events

**Files:**
- Modify: `src/zenflows/authz/event_facts.ex` (`process_controls`, load step)
- Modify: `src/zenflows/authz/event_policy.ex` (process rule, rule `:process`)
- Modify: `test/authz/events.test.exs`, `test/authz/events_api.test.exs` (factory processes → `Factory.insert_process!/1`)
- Test: `test/authz/event_policy.test.exs` (unit), `test/authz/events.test.exs` (domain)

**Interfaces:**
- Produces: `%EventFacts{process_ids: [id], process_controls: %{id => ObjectControl}}`; `EventPolicy.decide/3` may return `{:error, :forbidden, :process}`.

- [ ] **Step 1: Failing tests**
  - Unit (`event_policy.test.exs`): with `process_ids: [p]` and no control → `:process`; controlled by signer → ok; controlled by an org the signer administers → ok; agent rule still checked first (stranger → `:agent`).
  - Domain (`events.test.exs`): Bob's `cite` into Alice's process (`Factory.insert_process!(alice)`) → forbidden; into his own → ok; into a legacy `Factory.insert!(:process)` → forbidden.

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**
  - `EventFacts`: add `process_ids: []`, `process_controls: %{}` (struct and type). In `load/3`, after `controls` and before `admin_of`:

```elixir
process_ids = Enum.reject([Map.get(changes, :input_of_id), Map.get(changes, :output_of_id)], &is_nil/1)
process_controls = lock_process_controls(repo, process_ids)
```

  with `lock_process_controls/2` querying `ObjectControl` (`target_type == "process"`, `target_id in ^ids`, `order_by: target_id`, `lock: "FOR SHARE"`) into a map; add the process controllers to `admin_ids`; set both new fields.
  - `EventPolicy.decide/3` for `"event.create"`: after the agent rule and before `check_changes/2`:

```elixir
not Enum.all?(f.process_ids, &controls?(pid, %{f | controls: f.process_controls}, &1)) ->
	{:error, :forbidden, :process}
```

  (or a dedicated `process_ok?/2` helper reading `f.process_controls` — prefer the helper for clarity.)

- [ ] **Step 4: Slice-2 tests** — in `test/authz/events.test.exs` and
`test/authz/events_api.test.exs`, every Person-signed event whose
`input_of_id`/`output_of_id` comes from `Factory.insert!(:process)` must use
`Factory.insert_process!(<signer>)` (for the acceptProposal-shaped test,
the owner's process). Anonymous (`Factory.ctx()`) tests elsewhere are
unaffected.

- [ ] **Step 5: Run** — `./mann test test/authz/`, then `./mann test`.

- [ ] **Step 6: Commit**

```bash
git add src/zenflows/authz/event_facts.ex src/zenflows/authz/event_policy.ex test/authz/event_policy.test.exs test/authz/events.test.exs test/authz/events_api.test.exs
git commit -m "feat(authz): events attach only to processes the signer controls" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: SDK-flow GraphQL tests, concurrency, guards

**Files:**
- Test: `test/authz/proposals_api.test.exs`, `test/authz/concurrency_objects.test.exs`
- Modify: `test/authz/guard.test.exs`

- [ ] **Step 1: GraphQL flows** — `proposals_api.test.exs` (`AbsinCase`,
`run_as!/3`), documents copied from
`interfacer-client/src/graphql/operations.ts` (CREATE_PROCESS,
PROPOSE_CONTRIBUTION, CREATE_PROPOSAL, LINK_CONTRIBUTION_PROPOSAL_INTENT,
ACCEPT_PROPOSAL, SATISFY_INTENTS, REJECT_PROPOSAL, CREATE_INTENT,
LINK_PROPOSAL_AND_INTENT) with the same argument shapes:
  - proposeContribution as Bob (his process, intents, proposal, links) → all ok;
  - acceptProposal as Alice (her new process; cite/accept/modify events; satisfactions) → all ok;
  - a second proposal rejected as Alice (REJECT_PROPOSAL, three `finished: true` updates incl. the cite intent) → all ok;
  - Carol cannot run REJECT_PROPOSAL on Bob's intents (FORBIDDEN, intents unchanged);
  - sale proposal as a seller (CREATE_PROPOSAL, CREATE_INTENT item/payment, LINK_PROPOSAL_AND_INTENT) → ok.
  Use real fixtures: Alice's origin resource raised by Alice, Bob's fork raised by Bob (as in `test/authz/events_api.test.exs`).

- [ ] **Step 2: Concurrency** — `concurrency_objects.test.exs`
(`ExUnit.Case, async: false`, unboxed, patterns from
`test/authz/concurrency_events.test.exs`):
  - an event attaching to a process races `assignObjectControl` moving that
    process to another person (assign holds the control row `FOR UPDATE` in
    an open transaction; the event's `FOR SHARE` must block, then the event
    is denied once control moved); try/after release; full cleanup;
  - `updateIntent finished: true` by a party races `deleteIntent` by the
    controller — no exception; outcomes are `{:ok, _}`/`{:error, _}` pairs
    consistent with serialization.

- [ ] **Step 3: Guards** — `test/authz/guard.test.exs`: remove the 14
mutations from `@pending` (`create_process update_process delete_process
create_proposal update_proposal delete_proposal create_intent update_intent
delete_intent propose_intent delete_proposed_intent create_satisfaction
update_satisfaction delete_satisfaction`); add a test that, after creating
and deleting one process, proposal and intent through the domains as a
person, `zf_object_control` has no row whose target no longer exists
(query each target table).

- [ ] **Step 4: Run** — new files three times (`for i in 1 2 3; do ./mann test test/authz/concurrency_objects.test.exs || break; done`), then `./mann test`.

- [ ] **Step 5: Commit**

```bash
git add test/authz/proposals_api.test.exs test/authz/concurrency_objects.test.exs test/authz/guard.test.exs
git commit -m "test(authz): SDK proposal flows, object concurrency, guards" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Docs and final verification

**Files:**
- Modify: `docs/authz-processes-design.md` (status; `## 11. Deltas from the original draft` with the three plan deltas plus any execution rulings)
- Modify: `docs/authz-release-notes.md`

- [ ] **Step 1: Release notes** — status line: "CRUD, events, processes,
intents and proposals enforced; groups, plans, agreements and catalogue
types pending". New section "Processes, intents and proposals (slice 3)":
controller on create; others' processes/proposals/intents read-only; the
intent rules (own process may name the other side; named parties may
update; same-proposal `finished`); proposeIntent and satisfaction rules;
events/intents attach only to processes you control; **processes,
proposals and intents created before the upgrade are deny-all until
`assignObjectControl`**; new `objectControl` query and
`assignObjectControl` mutation; updated "still unauthorized" list.
Verify each statement against the code.

- [ ] **Step 2: Spec** — status `Implemented on feat/authz-processes`;
deltas section.

- [ ] **Step 3: Verification**

Run: `./mann mix compile --force 2>&1 | grep -i warning` → only the
pre-existing Jason.Encoder warning.
Run: `./mann test` → only the 7 known failures.

- [ ] **Step 4: Commit**

```bash
git add docs/authz-processes-design.md docs/authz-release-notes.md
git commit -m "docs(authz): processes, intents and proposals release notes" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
