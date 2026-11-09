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

# Authorization foundation (RBAC slice 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every CRUD write on resources, organizations, agent relationships,
relationship roles and persons is decided by a deny-by-default policy over a
verified execution context, and every permission change leaves an append-only
trace.

**Architecture:** A new `Zenflows.Authz` namespace (context, pure policy,
facts loaders, log, resource control, membership) is called from inside the
existing domain `Ecto.Multi` pipelines, so decision and write share one
PostgreSQL transaction with row locks. Organization roles are ValueFlows
`AgentRelationship`s with seeded system `AgentRelationshipRole`s. Resolvers
only build the context from the Absinthe resolution and pass it down.

**Tech Stack:** Elixir 1.14 / OTP 25, Ecto SQL + PostgreSQL, Absinthe 1.7.1,
ExUnit with `Ecto.Adapters.SQL.Sandbox`, `:telemetry` 1.2.

**Spec:** `docs/authz-foundation-design.md` (read it before starting; this
plan argues from it).

## Spec deltas (decided while planning — fold into the spec in Task 14)

1. Mutations out of scope are listed in a **test allowlist**
   (`test/authz/guard.test.exs`) instead of carrying
   `meta authz: :signed_pending`. Same guarantee (a new mutation fails the
   test until classified), ~55 fewer edits.
2. The partial unique index on active relationships is replaced by a
   per-organization `pg_advisory_xact_lock` plus an existence check inside
   grants/revokes: existing non-system duplicate relationships could make the
   index migration fail.
3. `ExecutionContext.service(name, request_id)` takes no action list; the
   action sets are fixed inside `ExecutionContext` so callers can't widen
   them. `:migration` additionally gets `organization.create` (the 2025 seed
   migration creates an organization).
4. Resources created under a `:migration` context get no control row at
   creation; the backfill migration (which runs later) covers them. A
   resource without control is deny-all (fail closed).
5. Deleting an Organization/Person that controls resources or takes part in
   relationships returns an explicit error instead of a raw FK exception.
6. Deleting a resource writes a `resource_control.remove` log entry.
7. API tests inject `req_user` into the Absinthe context (auth checks off)
   rather than producing real Zenroom signatures; `MW.Sign` is untouched and
   keeps its existing tests.
8. `zf_resource_control` has only `updated_at`, following this repo's
   `timestamps()` convention (`inserted_at: false`).

## Global Constraints

- Tabs for indentation, no indentation of top-level module code, trailing
  commas in multi-line literals (repo style guide).
- Every new file starts with the repo's AGPL SPDX header (copy from any
  existing `.ex` file).
- Config keys: `config :zenflows, Zenflows.Authz, enforce: true,
  allow_unchecked: false`; env vars `AUTHZ_ENFORCE` (default `"true"`),
  `AUTHZ_ALLOW_UNCHECKED` (default `"true"` only in `:test`, else `"false"`).
- The app refuses to start in `:prod` with `enforce: false` or
  `allow_unchecked: true`.
- System role keys: exactly `"org.admin"` and `"org.member"`.
- Log `service` values: `:gql | :admin_key | :import | :migration`.
- Control `source` values: `:creation | :backfill | :transfer | :admin`.
- GraphQL denial: `%{message: "forbidden", extensions: %{code: "FORBIDDEN"}}`;
  anonymous: `%{message: "unauthenticated", extensions: %{code:
  "UNAUTHENTICATED"}}`.
- Never log keys, signatures or request bodies in `zf_permission_log` or in
  deny telemetry.
- Commit messages end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Clients reading `data` on denial** — non-null mutation fields return
   `data: nil` plus `errors[].extensions.code`; a GUI expecting `data.x` must
   not be confused with a success. Pinned in Task 13 (asserts the full
   response shape, including `path`).
2. **String-keyed params** — `Schema.params()` allows string keys; a
   relationship created with `%{"relationship_id" => system_role}` must still
   go through the grant path, not the plain insert. Pinned in Task 7.
3. **Organizations with no admin after deploy** — every write is FORBIDDEN
   (even for the original creator) until `assignOrganizationAdmin`; after it,
   the assigned person can update. Pinned in Task 8.
4. **Re-granting after revocation** — a revoked relationship must not block a
   new grant of the same role ("already granted" only counts active rows).
   Pinned in Task 7.
5. **Fresh database** — the 2025 seed migration runs with the new code before
   the authz tables exist; it must not touch them. Pinned in Task 11 (fresh
   drop/create/migrate run).

---

### Task 0: Test environment baseline

**Files:**
- Create: `conf/env.sh` (ignored by git)

- [ ] **Step 1: Start PostgreSQL and the Zenroom service**

```bash
docker run -d --name zf-test-db -e POSTGRES_USER=zenflows -e POSTGRES_PASSWORD=zenflows -p 5432:5432 postgres:12-alpine
docker run -d --name zf-test-room -e HTTP_PORT=3000 -p 3000:3000 ghcr.io/interfacerproject/zenflows-crypto:latest
```

- [ ] **Step 2: Generate and fill `conf/env.sh`**

Run: `./mann env.setup`, then append:

```bash
export DB_USER=zenflows
export DB_PASS=zenflows
export DB_HOST=localhost
export DB_PORT=5432
export ROOM_URI=http://localhost:3000
export EMAIL_ADDR=test@example.com
export EMAIL_KEY=dummy
```

- [ ] **Step 3: Record the baseline**

Run: `MIX_ENV=test ./mann mix ecto.create && ./mann test 2>&1 | tee _build/baseline.txt | tail -5`
Expected: a summary line `N tests, M failures`. Keep `_build/baseline.txt`
(ignored): later tasks must not add failures beyond these M. If M > 0, list
the failing test names at the top of the PR description.

No commit (nothing tracked changed).

---

### Task 1: Schema — tables, columns, seeded system roles

**Files:**
- Create: `priv/repo/migrations/20261001100000_create_zf_authz.exs`
- Create: `src/zenflows/authz/resource_control.ex`
- Create: `src/zenflows/authz/permission_log.ex`
- Modify: `src/zenflows/vf/agent_relationship_role.ex` (add `system_key`)
- Modify: `src/zenflows/vf/agent_relationship.ex` (add `in_scope_of`, `revoked_at`, `system_changeset/2`)
- Test: `test/authz/schema.test.exs`

**Interfaces:**
- Produces: `Zenflows.Authz.ResourceControl` (`resource_id`, `controller_id`,
  `source`, `epoch`; `changeset/1,2`), `Zenflows.Authz.PermissionLog`
  (`changeset/1`), `AgentRelationshipRole.system_key :: nil | String.t()`,
  `AgentRelationship.in_scope_of_id`, `AgentRelationship.revoked_at`,
  `AgentRelationship.system_changeset/2`.

- [ ] **Step 1: Write the failing test**

`test/authz/schema.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Schema do
use ZenflowsTest.Help.EctoCase, async: true

alias Zenflows.Authz.{PermissionLog, ResourceControl}
alias Zenflows.VF.AgentRelationshipRole

test "system roles are seeded" do
	for key <- ["org.admin", "org.member"] do
		assert %AgentRelationshipRole{system_key: ^key} =
			Repo.get_by(AgentRelationshipRole, system_key: key)
	end
end

describe "zf_permission_log" do
	setup do
		log =
			%{service: :migration, action: "test", target_type: "x", target_id: Factory.id()}
			|> PermissionLog.changeset()
			|> Repo.insert!()
		%{log: log}
	end

	test "inserted_at is set by the database", %{log: log} do
		assert %DateTime{} = log.inserted_at
	end

	test "rejects UPDATE", %{log: log} do
		assert_raise Postgrex.Error, ~r/append-only/, fn ->
			log |> Ecto.Changeset.change(action: "changed") |> Repo.update!()
		end
	end

	test "rejects DELETE", %{log: log} do
		assert_raise Postgrex.Error, ~r/append-only/, fn -> Repo.delete!(log) end
	end
end

test "control row is removed with its resource" do
	res = Factory.insert!(:economic_resource)
	agent = Factory.insert!(:person)
	%{resource_id: res.id, controller_id: agent.id, source: :admin}
	|> ResourceControl.changeset()
	|> Repo.insert!(on_conflict: :nothing, conflict_target: :resource_id)

	Repo.delete!(res)
	assert Repo.get_by(ResourceControl, resource_id: res.id) == nil
end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./mann test test/authz/schema.test.exs`
Expected: compile error `module Zenflows.Authz.PermissionLog is not available`.

- [ ] **Step 3: Write the migration**

`priv/repo/migrations/20261001100000_create_zf_authz.exs` (SPDX header, then):

```elixir
defmodule Zenflows.DB.Repo.Migrations.Create_zf_authz do
use Ecto.Migration

alias Zenflows.DB.ID

def up() do
	create table("zf_resource_control", primary_key: false) do
		add :resource_id, references("vf_economic_resource", on_delete: :delete_all),
			primary_key: true
		add :controller_id, references("vf_agent"), null: false
		add :source, :string, null: false
		add :epoch, :integer, null: false, default: 0
		timestamps()
	end
	create index("zf_resource_control", [:controller_id])
	create constraint("zf_resource_control", :source_check,
		check: "source IN ('creation', 'backfill', 'transfer', 'admin')")

	create table("zf_permission_log") do
		add :actor_id, :binary_id
		add :service, :string, null: false
		add :action, :string, null: false
		add :target_type, :string, null: false
		add :target_id, :binary_id, null: false
		add :subject_id, :binary_id
		add :role_key, :string
		add :before, :map
		add :after, :map
		add :request_id, :string
		add :reason, :text
		add :inserted_at, :timestamptz, null: false, default: fragment("now()")
	end
	create index("zf_permission_log", [:target_type, :target_id])
	create index("zf_permission_log", [:subject_id])

	execute """
	CREATE FUNCTION zf_permission_log_append_only() RETURNS trigger
	LANGUAGE plpgsql AS $$
	BEGIN
		RAISE EXCEPTION 'zf_permission_log is append-only';
	END
	$$
	"""
	execute """
	CREATE TRIGGER zf_permission_log_append_only
	BEFORE UPDATE OR DELETE ON zf_permission_log
	FOR EACH ROW EXECUTE PROCEDURE zf_permission_log_append_only()
	"""

	alter table("vf_agent_relationship_role") do
		add :system_key, :string
	end
	create unique_index("vf_agent_relationship_role", [:system_key])

	alter table("vf_agent_relationship") do
		add :in_scope_of_id, references("vf_agent")
		add :revoked_at, :timestamptz
	end
	create index("vf_agent_relationship", [:object_id, :relationship_id],
		where: "revoked_at IS NULL")

	flush()

	execute(fn ->
		r = repo()
		now = DateTime.utc_now()
		for {key, label, inverse} <- [
			{"org.admin", "admin", "has admin"},
			{"org.member", "member", "has member"},
		] do
			{:ok, id} = ID.dump(ID.gen())
			r.query!("""
				INSERT INTO vf_agent_relationship_role
					(id, role_label, inverse_role_label, system_key, updated_at)
				VALUES ($1, $2, $3, $4, $5)
				""", [id, label, inverse, key, now])
		end
	end)
end

def down() do
	execute "DELETE FROM vf_agent_relationship WHERE relationship_id IN (SELECT id FROM vf_agent_relationship_role WHERE system_key IS NOT NULL)"
	execute "DELETE FROM vf_agent_relationship_role WHERE system_key IS NOT NULL"
	alter table("vf_agent_relationship") do
		remove :in_scope_of_id
		remove :revoked_at
	end
	alter table("vf_agent_relationship_role") do
		remove :system_key
	end
	execute "DROP TABLE zf_permission_log"
	execute "DROP FUNCTION zf_permission_log_append_only()"
	drop table("zf_resource_control")
end
end
```

- [ ] **Step 4: Write the schemas**

`src/zenflows/authz/resource_control.ex`:

```elixir
defmodule Zenflows.Authz.ResourceControl do
@moduledoc """
Administrative control of an EconomicResource.  Deliberately separate
from the ValueFlows `primaryAccountable`/`custodian` economic fields.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema
alias Zenflows.VF.{Agent, EconomicResource}

@type source() :: :creation | :backfill | :transfer | :admin
@type t() :: %__MODULE__{
	resource_id: Schema.id(),
	controller_id: Schema.id(),
	source: source(),
	epoch: non_neg_integer(),
}

@primary_key false
schema "zf_resource_control" do
	belongs_to :resource, EconomicResource, primary_key: true
	belongs_to :controller, Agent
	field :source, Ecto.Enum, values: [:creation, :backfill, :transfer, :admin]
	field :epoch, :integer, default: 0
	timestamps()
end

@reqr ~w[resource_id controller_id source]a
@cast @reqr ++ [:epoch]

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.assoc_constraint(:resource)
	|> Changeset.assoc_constraint(:controller)
	|> Changeset.unique_constraint(:resource_id, name: "zf_resource_control_pkey")
end
end
```

`src/zenflows/authz/permission_log.ex`:

```elixir
defmodule Zenflows.Authz.PermissionLog do
@moduledoc """
One append-only entry of `zf_permission_log`.  Write it only through
`Zenflows.Authz.Log`.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema

@type t() :: %__MODULE__{}

schema "zf_permission_log" do
	field :actor_id, Zenflows.DB.ID
	field :service, Ecto.Enum, values: [:gql, :admin_key, :import, :migration]
	field :action, :string
	field :target_type, :string
	field :target_id, Zenflows.DB.ID
	field :subject_id, Zenflows.DB.ID
	field :role_key, :string
	field :before, :map
	field :after, :map
	field :request_id, :string
	field :reason, :string
	field :inserted_at, :utc_datetime_usec, read_after_writes: true
end

@reqr ~w[service action target_type target_id]a
@cast @reqr ++ ~w[actor_id subject_id role_key before after request_id reason]a

@doc false
@spec changeset(Schema.params()) :: Changeset.t()
def changeset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
end
end
```

- [ ] **Step 5: Extend the VF schemas**

In `src/zenflows/vf/agent_relationship_role.ex`, add to `@type t()`
`system_key: String.t() | nil,` and inside `schema` after `:note`:

```elixir
	# Stable key of a system role (e.g. "org.admin"); never user-editable.
	field :system_key, :string
```

Do **not** add it to `@cast`.

In `src/zenflows/vf/agent_relationship.ex`, replace the `# in_scope_of`
comment lines in `@type`/`schema` with:

```elixir
	belongs_to :in_scope_of, Agent
	field :revoked_at, :utc_datetime_usec
```

(and `in_scope_of: Agent.t() | nil, revoked_at: DateTime.t() | nil,` in
`@type`), leave `@cast` unchanged, and add after `changeset/2`:

```elixir
@doc """
Changeset for system-role relationships (grants).  Only
`Zenflows.Authz.Membership` uses it; `in_scope_of` is the organization.
"""
@spec system_changeset(Schema.t(), Schema.params()) :: Changeset.t()
def system_changeset(schema, params) do
	schema
	|> Changeset.cast(params, @cast ++ [:in_scope_of_id])
	|> Changeset.validate_required(@reqr ++ [:in_scope_of_id])
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:subject)
	|> Changeset.assoc_constraint(:object)
	|> Changeset.assoc_constraint(:relationship)
	|> Changeset.assoc_constraint(:in_scope_of)
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `./mann test test/authz/schema.test.exs`
Expected: 5 tests, 0 failures.

- [ ] **Step 7: Run the full suite**

Run: `./mann test`
Expected: no failures beyond `_build/baseline.txt`.

- [ ] **Step 8: Commit**

```bash
git add priv/repo/migrations/20261001100000_create_zf_authz.exs src/zenflows/authz src/zenflows/vf/agent_relationship.ex src/zenflows/vf/agent_relationship_role.ex test/authz/schema.test.exs
git commit -m "feat(authz): add resource control, permission log and system roles" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Configuration, ExecutionContext, request id, boot guard

**Files:**
- Create: `src/zenflows/authz/config.ex`
- Create: `src/zenflows/authz/execution_context.ex`
- Modify: `conf/runtime.exs` (append authz block)
- Modify: `conf/buildtime.exs` (record build env)
- Modify: `src/zenflows/application.ex:24` (call `validate!/0` first in `start/2`)
- Modify: `src/zenflows/web/mw/gql_context.ex` (request id)
- Test: `test/authz/config.test.exs`, `test/authz/execution_context.test.exs`, `test/web/gql_context.test.exs`

**Interfaces:**
- Produces:
  - `Zenflows.Authz.Config.opts() :: [enforce: boolean(), allow_unchecked: boolean()]`
  - `Zenflows.Authz.Config.validate!(env :: atom(), opts) :: :ok` (raises)
  - `%Zenflows.Authz.ExecutionContext{principal, via, request_id}` with
    `principal :: %Person{} | {:service, name, MapSet.t(String.t())} | :anonymous`
  - `ExecutionContext.from_resolution(%{context: map()}) :: t()`
  - `ExecutionContext.admin_key(%{context: map()}) :: t()`
  - `ExecutionContext.service(:import | :migration, request_id :: nil | String.t()) :: t()`
  - `ExecutionContext.actor_id(t()) :: nil | String.t()`
  - GQL context key `:request_id` (set when header `zenflows-request-id` is valid)

- [ ] **Step 1: Write the failing tests**

`test/authz/config.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Config do
use ExUnit.Case, async: true

alias Zenflows.Authz.Config

test "prod refuses enforce: false" do
	assert_raise RuntimeError, ~r/AUTHZ_ENFORCE/, fn ->
		Config.validate!(:prod, enforce: false, allow_unchecked: false)
	end
end

test "prod refuses allow_unchecked: true" do
	assert_raise RuntimeError, ~r/AUTHZ_ALLOW_UNCHECKED/, fn ->
		Config.validate!(:prod, enforce: true, allow_unchecked: true)
	end
end

test "prod accepts the safe values" do
	assert :ok = Config.validate!(:prod, enforce: true, allow_unchecked: false)
end

test "non-prod accepts anything" do
	assert :ok = Config.validate!(:dev, enforce: false, allow_unchecked: true)
end

test "test env defaults allow unchecked anonymous calls" do
	assert Config.opts() == [enforce: true, allow_unchecked: true]
end
end
```

`test/authz/execution_context.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.ExecutionContext do
use ExUnit.Case, async: true

alias Zenflows.Authz.ExecutionContext, as: Ctx
alias Zenflows.VF.Person

test "from_resolution: person when req_user is set" do
	per = %Person{id: Zenflows.DB.ID.gen()}
	ctx = Ctx.from_resolution(%{context: %{req_user: per, request_id: "r1"}})
	assert %Ctx{principal: ^per, via: :gql, request_id: "r1"} = ctx
	assert Ctx.actor_id(ctx) == per.id
end

test "from_resolution: anonymous otherwise, with a generated request id" do
	ctx = Ctx.from_resolution(%{context: %{}})
	assert %Ctx{principal: :anonymous, via: :gql, request_id: rid} = ctx
	assert byte_size(rid) == 26
	assert Ctx.actor_id(ctx) == nil
end

test "admin_key: service principal only when calls are authenticated" do
	ctx = Ctx.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})
	assert %Ctx{principal: {:service, :admin_key, actions}, via: :admin_key} = ctx
	assert MapSet.member?(actions, "person.create")
	refute MapSet.member?(actions, "resource.update")

	assert %Ctx{principal: :anonymous} =
		Ctx.admin_key(%{context: %{authenticate_calls?: false}})
end

test "service: fixed action sets" do
	assert %Ctx{principal: {:service, :import, a}, via: :import, request_id: "r"} =
		Ctx.service(:import, "r")
	assert MapSet.member?(a, "relationship.grant")
	assert %Ctx{principal: {:service, :migration, m}} = Ctx.service(:migration, nil)
	assert MapSet.member?(m, "organization.create")
	assert_raise FunctionClauseError, fn -> Ctx.service(:admin_key, nil) end
end
end
```

`test/web/gql_context.test.exs`:

```elixir
defmodule ZenflowsTest.Web.GQLContext do
use ExUnit.Case, async: true
import Plug.Test
import Plug.Conn

alias Zenflows.Web.MW.GQLContext

defp ctx(conn), do: GQLContext.call(conn, []).private.absinthe.context

test "valid request id header is kept" do
	conn = conn(:post, "/api") |> put_req_header("zenflows-request-id", "abc-123_X")
	assert %{request_id: "abc-123_X"} = ctx(conn)
end

test "invalid request id header is ignored" do
	conn = conn(:post, "/api") |> put_req_header("zenflows-request-id", "bad id;drop")
	refute Map.has_key?(ctx(conn), :request_id)
end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./mann test test/authz/config.test.exs test/authz/execution_context.test.exs test/web/gql_context.test.exs`
Expected: compile errors (`Zenflows.Authz.Config` not available).

- [ ] **Step 3: Implement config**

Append to `conf/runtime.exs`:

```elixir
#
# authz
#
authz_unchecked_default = if config_env() == :test, do: "true", else: "false"
config :zenflows, Zenflows.Authz,
	enforce: get_env("AUTHZ_ENFORCE", "true") != "false",
	allow_unchecked: get_env("AUTHZ_ALLOW_UNCHECKED", authz_unchecked_default) == "true"
```

Append to `conf/buildtime.exs` (before the `if config_env() == :test` block):

```elixir
config :zenflows, :build_env, config_env()
```

`src/zenflows/authz/config.ex`:

```elixir
defmodule Zenflows.Authz.Config do
@moduledoc "Runtime configuration of authorization."

@type opts() :: [enforce: boolean(), allow_unchecked: boolean()]

@doc "Current options, read from `config :zenflows, Zenflows.Authz`."
@spec opts() :: opts()
def opts() do
	conf = Application.get_env(:zenflows, Zenflows.Authz, [])
	[
		enforce: Keyword.get(conf, :enforce, true),
		allow_unchecked: Keyword.get(conf, :allow_unchecked, false),
	]
end

@doc "Raise if a permissive option is set in production."
@spec validate!(atom(), opts()) :: :ok
def validate!(env \\ Application.get_env(:zenflows, :build_env, :prod), opts \\ opts())
def validate!(:prod, opts) do
	cond do
		not Keyword.fetch!(opts, :enforce) ->
			raise "AUTHZ_ENFORCE=false is not allowed in production"
		Keyword.fetch!(opts, :allow_unchecked) ->
			raise "AUTHZ_ALLOW_UNCHECKED=true is not allowed in production"
		true -> :ok
	end
end
def validate!(_env, _opts), do: :ok
end
```

In `src/zenflows/application.ex`, make the first line of `start/2`:

```elixir
	:ok = Zenflows.Authz.Config.validate!()
```

- [ ] **Step 4: Implement ExecutionContext**

`src/zenflows/authz/execution_context.ex`:

```elixir
defmodule Zenflows.Authz.ExecutionContext do
@moduledoc """
Who is acting, through which channel, for which request.

Build it only with the constructors below.  It is never built from
GraphQL arguments: the Person comes from `MW.Sign` (`req_user`), the
admin-key principal only from fields guarded by `MW.Admin`.
"""

alias Zenflows.DB.ID
alias Zenflows.VF.Person

@type service_name() :: :admin_key | :import | :migration
@type principal() ::
	Person.t()
	| {:service, service_name(), MapSet.t(String.t())}
	| :anonymous
@type via() :: :gql | :admin_key | :import | :migration
@type t() :: %__MODULE__{principal: principal(), via: via(), request_id: String.t()}

@enforce_keys [:principal, :via, :request_id]
defstruct @enforce_keys

@service_actions %{
	admin_key: ~w[person.create person.delete sw_pass.import organization.assign_admin],
	import: ~w[resource.create organization.create relationship.grant],
	migration: ~w[resource.create organization.create resource_control.set],
}

@doc "Context of a signed GraphQL field."
@spec from_resolution(%{context: map()}) :: t()
def from_resolution(%{context: c}) do
	principal =
		case c do
			%{req_user: %Person{} = per} -> per
			_ -> :anonymous
		end
	%__MODULE__{principal: principal, via: :gql, request_id: request_id(c)}
end

@doc """
Context of an `only_admin?` field.  Call only from resolvers of such
fields: the resolver runs only after `MW.Admin` accepted the key.
"""
@spec admin_key(%{context: map()}) :: t()
def admin_key(%{context: c}) do
	principal =
		if c[:authenticate_calls?] == true and is_binary(c[:gql_admin]),
			do: service_principal(:admin_key),
			else: :anonymous
	%__MODULE__{principal: principal, via: :admin_key, request_id: request_id(c)}
end

@doc "Context of import jobs and migrations.  Callers are allowlisted in tests."
@spec service(:import | :migration, nil | String.t()) :: t()
def service(name, request_id) when name in [:import, :migration] do
	%__MODULE__{
		principal: service_principal(name),
		via: name,
		request_id: request_id || ID.gen(),
	}
end

@doc "The acting Person's id, or nil for services and anonymous calls."
@spec actor_id(t()) :: nil | String.t()
def actor_id(%__MODULE__{principal: %Person{id: id}}), do: id
def actor_id(%__MODULE__{}), do: nil

defp service_principal(name),
	do: {:service, name, MapSet.new(Map.fetch!(@service_actions, name))}

defp request_id(%{request_id: rid}) when is_binary(rid), do: rid
defp request_id(_), do: ID.gen()
end
```

- [ ] **Step 5: Request id in the GQL context**

In `src/zenflows/web/mw/gql_context.ex`, change `call/2`'s pipeline to:

```elixir
	ctx =
		%{}
		|> set_admin(conn)
		|> set_user_and_sign_and_body(conn)
		|> set_request_id(conn)
```

and add before the final `end`:

```elixir
@request_id_re ~r/\A[A-Za-z0-9_-]{1,64}\z/

# Set `request_id` from the headers, if it is well-formed.  It is only
# used to correlate logs; it is never trusted for decisions.
@spec set_request_id(map(), Conn.t()) :: map()
defp set_request_id(ctx, conn) do
	with [rid | _] <- Conn.get_req_header(conn, "zenflows-request-id"),
			true <- Regex.match?(@request_id_re, rid) do
		Map.put(ctx, :request_id, rid)
	else _ ->
		ctx
	end
end
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `./mann test test/authz/config.test.exs test/authz/execution_context.test.exs test/web/gql_context.test.exs`
Expected: 11 tests, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add conf/runtime.exs conf/buildtime.exs src/zenflows/application.ex src/zenflows/authz src/zenflows/web/mw/gql_context.ex test/authz test/web
git commit -m "feat(authz): add execution context, config and boot guard" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Pure policy

**Files:**
- Create: `src/zenflows/authz/facts.ex` (struct only in this task)
- Create: `src/zenflows/authz/policy.ex`
- Test: `test/authz/policy.test.exs`

**Interfaces:**
- Consumes: `ExecutionContext` (Task 2).
- Produces:
  - `%Zenflows.Authz.Facts{target, control, admin_of, role_key, new_subject_id, active_admin_count}`
    (defaults: `nil`, `nil`, `MapSet.new()`, `nil`, `nil`, `nil`)
  - `Zenflows.Authz.Policy.actions() :: [String.t()]`
  - `Zenflows.Authz.Policy.authorize(ExecutionContext.t(), String.t(), Facts.t(), Config.opts()) :: :ok | {:error, :forbidden | :unauthenticated}`

- [ ] **Step 1: Write the failing test**

`test/authz/policy.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Policy do
use ExUnit.Case, async: true

alias Zenflows.Authz.{ExecutionContext, Facts, Policy, ResourceControl}
alias Zenflows.DB.ID
alias Zenflows.VF.{AgentRelationship, AgentRelationshipRole, Organization, Person}

@strict [enforce: true, allow_unchecked: false]

setup do
	alice = %Person{id: ID.gen()}
	bob = %Person{id: ID.gen()}
	org = %Organization{id: ID.gen()}
	%{
		alice: alice, bob: bob, org: org,
		as_alice: ExecutionContext.from_resolution(%{context: %{req_user: alice}}),
		as_bob: ExecutionContext.from_resolution(%{context: %{req_user: bob}}),
		anon: ExecutionContext.from_resolution(%{context: %{}}),
		admin_key: ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}}),
		import: ExecutionContext.service(:import, nil),
	}
end

defp auth(ctx, action, facts, opts \\ @strict), do: Policy.authorize(ctx, action, facts, opts)
defp admins(ids), do: MapSet.new(ids)

test "unknown action is forbidden for everyone", c do
	assert {:error, :forbidden} = auth(c.as_alice, "resource.fly", %Facts{})
	assert {:error, :forbidden} = auth(c.admin_key, "resource.fly", %Facts{})
end

test "anonymous is unauthenticated unless allow_unchecked", c do
	assert {:error, :unauthenticated} = auth(c.anon, "resource.update", %Facts{})
	assert :ok = auth(c.anon, "resource.update", %Facts{}, enforce: true, allow_unchecked: true)
end

test "services are limited to their action set", c do
	assert :ok = auth(c.admin_key, "person.create", %Facts{})
	assert {:error, :forbidden} = auth(c.admin_key, "resource.update", %Facts{})
	assert :ok = auth(c.import, "relationship.grant", %Facts{})
	assert {:error, :forbidden} = auth(c.import, "person.delete", %Facts{})
end

describe "resource.update / resource.delete" do
	for action <- ["resource.update", "resource.delete"] do
		test "#{action}: controller allowed, others denied", c do
			f = %Facts{control: %ResourceControl{controller_id: c.alice.id}}
			assert :ok = auth(c.as_alice, unquote(action), f)
			assert {:error, :forbidden} = auth(c.as_bob, unquote(action), f)
		end

		test "#{action}: admin of controlling org allowed", c do
			f = %Facts{control: %ResourceControl{controller_id: c.org.id}, admin_of: admins([c.org.id])}
			assert :ok = auth(c.as_bob, unquote(action), f)
			assert {:error, :forbidden} = auth(c.as_bob, unquote(action), %{f | admin_of: admins([])})
		end

		test "#{action}: no control row is deny-all", c do
			assert {:error, :forbidden} = auth(c.as_alice, unquote(action), %Facts{control: nil})
		end
	end
end

test "organization.update/delete need active admin", c do
	f = %Facts{target: c.org, admin_of: admins([c.org.id])}
	assert :ok = auth(c.as_alice, "organization.update", f)
	assert :ok = auth(c.as_alice, "organization.delete", f)
	assert {:error, :forbidden} = auth(c.as_alice, "organization.update", %{f | admin_of: admins([])})
	assert {:error, :forbidden} = auth(c.as_alice, "organization.update", %Facts{target: nil})
end

test "organization.create and resource.create: any person", c do
	assert :ok = auth(c.as_bob, "organization.create", %Facts{})
	assert :ok = auth(c.as_bob, "resource.create", %Facts{})
end

test "organization.assign_admin: admin key only", c do
	assert {:error, :forbidden} = auth(c.as_alice, "organization.assign_admin", %Facts{target: c.org, admin_of: admins([c.org.id])})
	assert :ok = auth(c.admin_key, "organization.assign_admin", %Facts{})
end

test "relationship.grant needs admin of the object org", c do
	f = %Facts{target: %{object_id: c.org.id}, role_key: "org.admin", admin_of: admins([c.org.id])}
	assert :ok = auth(c.as_alice, "relationship.grant", f)
	assert {:error, :forbidden} = auth(c.as_alice, "relationship.grant", %{f | admin_of: admins([])})
end

test "relationship.revoke: admin, and never the last admin", c do
	rel = %AgentRelationship{object_id: c.org.id, subject_id: c.bob.id}
	f = %Facts{target: rel, role_key: "org.admin", admin_of: admins([c.org.id]), active_admin_count: 2}
	assert :ok = auth(c.as_alice, "relationship.revoke", f)
	assert {:error, :forbidden} = auth(c.as_alice, "relationship.revoke", %{f | active_admin_count: 1})
	assert :ok = auth(c.as_alice, "relationship.revoke", %{f | role_key: "org.member", active_admin_count: 1})
	assert {:error, :forbidden} = auth(c.as_bob, "relationship.revoke", %{f | admin_of: admins([])})
end

test "non-system relationship create/delete: subject or admin of subject", c do
	for action <- ["relationship.create", "relationship.delete"] do
		assert :ok = auth(c.as_bob, action, %Facts{target: %{subject_id: c.bob.id}})
		assert {:error, :forbidden} = auth(c.as_bob, action, %Facts{target: %{subject_id: c.alice.id}})
		assert :ok = auth(c.as_bob, action, %Facts{target: %{subject_id: c.org.id}, admin_of: admins([c.org.id])})
		assert {:error, :forbidden} = auth(c.as_bob, action, %Facts{target: nil})
	end
end

test "relationship.update", c do
	rel = %AgentRelationship{subject_id: c.bob.id, object_id: c.alice.id}
	assert :ok = auth(c.as_bob, "relationship.update", %Facts{target: rel})
	assert {:error, :forbidden} =
		auth(c.as_bob, "relationship.update", %Facts{target: rel, new_subject_id: c.alice.id})
	assert {:error, :forbidden} = auth(c.as_alice, "relationship.update", %Facts{target: rel})

	sys = %AgentRelationship{subject_id: c.bob.id, object_id: c.org.id}
	assert {:error, :forbidden} = auth(c.as_bob, "relationship.update", %Facts{target: sys, role_key: "org.admin"})
	assert :ok = auth(c.as_alice, "relationship.update", %Facts{target: sys, role_key: "org.admin", admin_of: admins([c.org.id])})
end

test "role.update/delete: never on system roles", c do
	for action <- ["role.update", "role.delete"] do
		assert :ok = auth(c.as_bob, action, %Facts{target: %AgentRelationshipRole{system_key: nil}})
		assert {:error, :forbidden} = auth(c.as_bob, action, %Facts{target: %AgentRelationshipRole{system_key: "org.admin"}})
	end
end

test "person.update: self only", c do
	assert :ok = auth(c.as_alice, "person.update", %Facts{target: c.alice})
	assert {:error, :forbidden} = auth(c.as_bob, "person.update", %Facts{target: c.alice})
end

test "person.create/delete and sw_pass.import: never for persons", c do
	for action <- ["person.create", "person.delete", "sw_pass.import", "resource_control.set"] do
		assert {:error, :forbidden} = auth(c.as_alice, action, %Facts{target: c.alice})
	end
end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./mann test test/authz/policy.test.exs`
Expected: compile error, `Zenflows.Authz.Facts` not available.

- [ ] **Step 3: Implement Facts (struct) and Policy**

`src/zenflows/authz/facts.ex`:

```elixir
defmodule Zenflows.Authz.Facts do
@moduledoc """
Everything a policy decision may look at.  Domain functions load it
(with row locks) inside their transaction, then hand it to the policy.
"""

alias Zenflows.Authz.ResourceControl

@type t() :: %__MODULE__{
	target: nil | struct() | map(),
	control: nil | ResourceControl.t(),
	admin_of: MapSet.t(String.t()),
	role_key: nil | String.t(),
	new_subject_id: nil | String.t(),
	active_admin_count: nil | non_neg_integer(),
}

defstruct target: nil,
	control: nil,
	admin_of: MapSet.new(),
	role_key: nil,
	new_subject_id: nil,
	active_admin_count: nil
end
```

`src/zenflows/authz/policy.ex`:

```elixir
defmodule Zenflows.Authz.Policy do
@moduledoc """
Deny-by-default authorization decisions.  Pure: it never touches the
database; everything it needs is in `Zenflows.Authz.Facts`.
"""

alias Zenflows.Authz.{Config, ExecutionContext, Facts}
alias Zenflows.VF.Person

@actions ~w[
	resource.create resource.update resource.delete
	organization.create organization.update organization.delete
	organization.assign_admin
	relationship.grant relationship.revoke
	relationship.create relationship.update relationship.delete
	role.update role.delete
	person.create person.update person.delete
	sw_pass.import resource_control.set
]

@doc "Every action the policy knows about."
@spec actions() :: [String.t()]
def actions(), do: @actions

@spec authorize(ExecutionContext.t(), String.t(), Facts.t(), Config.opts())
	:: :ok | {:error, :forbidden | :unauthenticated}
def authorize(%ExecutionContext{principal: principal}, action, %Facts{} = facts, opts) do
	if action in @actions,
		do: decide(principal, action, facts, opts),
		else: {:error, :forbidden}
end

defp decide(:anonymous, _action, _facts, opts) do
	if Keyword.get(opts, :allow_unchecked, false),
		do: :ok,
		else: {:error, :unauthenticated}
end
defp decide({:service, _name, allowed}, action, _facts, _opts) do
	if MapSet.member?(allowed, action), do: :ok, else: {:error, :forbidden}
end
defp decide(%Person{id: pid}, action, facts, _opts) do
	if person_may?(pid, action, facts), do: :ok, else: {:error, :forbidden}
end

# Event authorization is the next slice: any signer may create
# resources (through events) and organizations.
defp person_may?(_pid, action, _f) when action in ~w[resource.create organization.create],
	do: true
defp person_may?(pid, action, %Facts{control: %{controller_id: cid}} = f)
		when action in ~w[resource.update resource.delete],
	do: cid == pid or admin?(f, cid)
defp person_may?(_pid, action, %Facts{target: %{id: oid}} = f)
		when action in ~w[organization.update organization.delete],
	do: admin?(f, oid)
defp person_may?(_pid, "relationship.grant", %Facts{target: %{object_id: oid}} = f),
	do: admin?(f, oid)
defp person_may?(_pid, "relationship.revoke", %Facts{target: %{object_id: oid}, role_key: rk} = f),
	do: admin?(f, oid) and (rk != "org.admin" or (f.active_admin_count || 0) > 1)
defp person_may?(pid, action, %Facts{target: %{subject_id: sid}} = f)
		when action in ~w[relationship.create relationship.delete],
	do: subject_ok?(pid, f, sid)
defp person_may?(pid, "relationship.update",
		%Facts{target: %{subject_id: sid, object_id: oid}, role_key: rk} = f) do
	if rk != nil do
		admin?(f, oid)
	else
		subject_ok?(pid, f, sid)
			and (f.new_subject_id == nil or subject_ok?(pid, f, f.new_subject_id))
	end
end
defp person_may?(_pid, action, %Facts{target: %{system_key: sk}})
		when action in ~w[role.update role.delete],
	do: sk == nil
defp person_may?(pid, "person.update", %Facts{target: %Person{id: id}}),
	do: id == pid
defp person_may?(_pid, _action, _facts), do: false

defp admin?(%Facts{admin_of: set}, id), do: MapSet.member?(set, id)

defp subject_ok?(pid, f, sid), do: sid == pid or admin?(f, sid)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./mann test test/authz/policy.test.exs`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add src/zenflows/authz/facts.ex src/zenflows/authz/policy.ex test/authz/policy.test.exs
git commit -m "feat(authz): add deny-by-default policy" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Runtime glue — roles, facts loaders, log, authorize-in-multi, errors

**Files:**
- Create: `src/zenflows/authz/roles.ex`
- Create: `src/zenflows/authz/log.ex`
- Create: `src/zenflows/authz.ex`
- Modify: `src/zenflows/authz/facts.ex` (add loaders)
- Modify: `src/zenflows/gql/mw/errors.ex` (two clauses)
- Modify: `test/help/factory.ex` (`ctx/0`, `ctx/1`, `insert_admin!/2`)
- Test: `test/authz/authz.test.exs`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `Zenflows.Authz.Roles.keys/0`, `id!(repo, key) :: String.t()`, `key_of(repo, nil | role_id) :: nil | String.t()`
  - `Zenflows.Authz.Facts.admin_of(repo, ctx) :: MapSet.t()`,
    `for_resource(repo, ctx, id)`, `for_organization(repo, ctx, id)`,
    `for_person(repo, id)` — all `:: Facts.t()`, rows locked `FOR UPDATE`,
    admin relationships `FOR SHARE`
  - `Zenflows.Authz.Log.insert(repo, ctx, entry) :: {:ok, PermissionLog.t()} | {:error, Changeset.t()}`
  - `Zenflows.Authz.Log.multi_insert(multi, key, ctx, (changes -> nil | entry)) :: Multi.t()`
    where `entry :: %{action, target_type, target_id, optional subject_id, role_key, before, after, reason}`
  - `Zenflows.Authz.authorize(ctx, action, facts, opts \\ Config.opts()) :: :ok | {:error, :forbidden | :unauthenticated}`
  - `Zenflows.Authz.multi_authorize(multi, key, ctx, action, (repo, changes -> Facts.t())) :: Multi.t()` — on success `changes[key]` is the `Facts`
  - `Zenflows.Authz.multi_target(multi, key, authz_key) :: Multi.t()` — `changes[key]` is `facts.target`, or `{:error, "not found"}`
  - Telemetry event `[:zenflows, :authz, :deny]`, measurements `%{count: 1}`, metadata `%{actor_id, action, target_id, request_id, reason, enforced}`
  - `Factory.ctx() :: ExecutionContext.t()` (anonymous), `Factory.ctx(person)`, `Factory.insert_admin!(person, org) :: AgentRelationship.t()`

- [ ] **Step 1: Add factory helpers**

In `test/help/factory.ex` add `alias Zenflows.Authz.{ExecutionContext, Roles}` next to the existing aliases, and before the final `end`:

```elixir
@doc "Anonymous context; allowed everything in tests (allow_unchecked)."
@spec ctx() :: ExecutionContext.t()
def ctx(), do: ExecutionContext.from_resolution(%{context: %{}})

@doc "Context acting as `per`; fully enforced."
@spec ctx(VF.Person.t()) :: ExecutionContext.t()
def ctx(%VF.Person{} = per), do: ExecutionContext.from_resolution(%{context: %{req_user: per}})

@doc "Make `per` an active org.admin of `org` without logging (fixtures only)."
@spec insert_admin!(VF.Person.t(), VF.Organization.t()) :: VF.AgentRelationship.t()
def insert_admin!(per, org) do
	Zenflows.DB.Repo.insert!(%VF.AgentRelationship{
		subject_id: per.id,
		object_id: org.id,
		in_scope_of_id: org.id,
		relationship_id: Roles.id!(Zenflows.DB.Repo, "org.admin"),
	})
end
```

- [ ] **Step 2: Write the failing test**

`test/authz/authz.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Authz do
use ZenflowsTest.Help.EctoCase, async: true

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{Facts, Log, PermissionLog}

setup do
	alice = Factory.insert!(:person)
	org = Factory.insert!(:organization)
	%{alice: alice, org: org}
end

test "admin_of: active admin relationships only", %{alice: alice, org: org} do
	rel = Factory.insert_admin!(alice, org)
	assert Facts.admin_of(Repo, Factory.ctx(alice)) == MapSet.new([org.id])

	rel |> Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update!()
	assert Facts.admin_of(Repo, Factory.ctx(alice)) == MapSet.new()
	assert Facts.admin_of(Repo, Factory.ctx()) == MapSet.new()
end

test "multi_authorize aborts the transaction on deny", %{alice: alice, org: org} do
	assert {:error, :authz, :forbidden, _} =
		Multi.new()
		|> Authz.multi_authorize(:authz, Factory.ctx(alice), "organization.update",
			fn repo, _ -> Facts.for_organization(repo, Factory.ctx(alice), org.id) end)
		|> Multi.run(:never, fn _, _ -> flunk("ran after deny") end)
		|> Repo.transaction()
end

test "multi_target: not found when authorized but missing" do
	assert {:error, :one, "not found", _} =
		Multi.new()
		|> Authz.multi_authorize(:authz, Factory.ctx(), "organization.update",
			fn repo, _ -> Facts.for_organization(repo, Factory.ctx(), Factory.id()) end)
		|> Authz.multi_target(:one, :authz)
		|> Repo.transaction()
end

test "deny emits telemetry; enforce: false lets it through", %{alice: alice, org: org} do
	ref = make_ref()
	pid = self()
	:telemetry.attach("authz-test-#{inspect(ref)}", [:zenflows, :authz, :deny],
		fn _, m, meta, _ -> send(pid, {:deny, m, meta}) end, nil)
	on_exit(fn -> :telemetry.detach("authz-test-#{inspect(ref)}") end)

	facts = Facts.for_organization(Repo, Factory.ctx(alice), org.id)
	assert :ok = Authz.authorize(Factory.ctx(alice), "organization.update", facts,
		enforce: false, allow_unchecked: false)
	alice_id = alice.id
	org_id = org.id
	assert_received {:deny, %{count: 1},
		%{actor_id: ^alice_id, action: "organization.update", target_id: ^org_id, enforced: false}}
end

test "Log.multi_insert fills actor, service and request id from ctx", %{alice: alice, org: org} do
	ctx = Factory.ctx(alice)
	{:ok, %{log: log}} =
		Multi.new()
		|> Log.multi_insert(:log, ctx, fn _ ->
			%{action: "test", target_type: "organization", target_id: org.id, actor_id: "forged"}
		end)
		|> Repo.transaction()
	assert %PermissionLog{actor_id: actor, service: :gql, request_id: rid} = log
	assert actor == alice.id
	assert rid == ctx.request_id
end

test "a failing log entry rolls back the change it records" do
	assert {:error, :log, %Ecto.Changeset{}, _} =
		Multi.new()
		|> Multi.insert(:org, Zenflows.VF.Organization.changeset(%{name: "rollback-me"}))
		|> Log.multi_insert(:log, Factory.ctx(), fn _ ->
			%{action: "x", target_type: "organization", target_id: nil}
		end)
		|> Repo.transaction()
	assert Repo.get_by(Zenflows.VF.Organization, name: "rollback-me") == nil
end

test "Log.multi_insert skips nil entries" do
	assert {:ok, %{log: nil}} =
		Multi.new() |> Log.multi_insert(:log, Factory.ctx(), fn _ -> nil end) |> Repo.transaction()
end

test "MW.Errors maps authz errors to coded GraphQL errors" do
	res = Zenflows.GQL.MW.Errors.call(%Absinthe.Resolution{errors: [:forbidden, :unauthenticated]}, [])
	assert res.errors == [
		%{message: "forbidden", extensions: %{code: "FORBIDDEN"}},
		%{message: "unauthenticated", extensions: %{code: "UNAUTHENTICATED"}},
	]
end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./mann test test/authz/authz.test.exs`
Expected: compile error, `Zenflows.Authz.Roles` not available.

- [ ] **Step 4: Implement Roles**

`src/zenflows/authz/roles.ex`:

```elixir
defmodule Zenflows.Authz.Roles do
@moduledoc "System AgentRelationshipRoles, looked up by their stable `system_key`."

import Ecto.Query

alias Zenflows.VF.AgentRelationshipRole

@keys ~w[org.admin org.member]

@spec keys() :: [String.t()]
def keys(), do: @keys

@spec id!(Ecto.Repo.t(), String.t()) :: String.t()
def id!(repo, key) when key in @keys do
	repo.one!(from r in AgentRelationshipRole, where: r.system_key == ^key, select: r.id)
end

@doc "The system key of a role id, or nil for user-defined roles."
@spec key_of(Ecto.Repo.t(), nil | String.t()) :: nil | String.t()
def key_of(_repo, nil), do: nil
def key_of(repo, role_id) do
	repo.one(from r in AgentRelationshipRole, where: r.id == ^role_id, select: r.system_key)
end
end
```

- [ ] **Step 5: Add the loaders to Facts**

In `src/zenflows/authz/facts.ex`, add after the `alias` line:

```elixir
import Ecto.Query

alias Zenflows.Authz.{ExecutionContext, Roles}
alias Zenflows.VF.{AgentRelationship, EconomicResource, Organization, Person}
```

and after `defstruct`:

```elixir
@doc """
Organizations where the acting Person is an active `org.admin`.  Locks
the relationship rows FOR SHARE so a concurrent revoke serializes with
the decision.
"""
@spec admin_of(Ecto.Repo.t(), ExecutionContext.t()) :: MapSet.t(String.t())
def admin_of(repo, %ExecutionContext{principal: %Person{id: pid}}) do
	admin_role = Roles.id!(repo, "org.admin")
	from(r in AgentRelationship,
		where: r.subject_id == ^pid
			and r.relationship_id == ^admin_role
			and is_nil(r.revoked_at),
		select: r.object_id,
		lock: "FOR SHARE")
	|> repo.all()
	|> MapSet.new()
end
def admin_of(_repo, _ctx), do: MapSet.new()

@spec for_resource(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_resource(repo, ctx, id) do
	%__MODULE__{
		target: repo.one(from r in EconomicResource, where: r.id == ^id, lock: "FOR UPDATE"),
		control: repo.one(from c in ResourceControl, where: c.resource_id == ^id, lock: "FOR UPDATE"),
		admin_of: admin_of(repo, ctx),
	}
end

@spec for_organization(Ecto.Repo.t(), ExecutionContext.t(), String.t()) :: t()
def for_organization(repo, ctx, id) do
	%__MODULE__{
		target: repo.one(from o in Organization,
			where: o.id == ^id and o.type == :org, lock: "FOR UPDATE"),
		admin_of: admin_of(repo, ctx),
	}
end

@spec for_person(Ecto.Repo.t(), String.t()) :: t()
def for_person(repo, id) do
	%__MODULE__{
		target: repo.one(from p in Person, where: p.id == ^id and p.type == :per, lock: "FOR UPDATE"),
	}
end
```

- [ ] **Step 6: Implement Log and Authz**

`src/zenflows/authz/log.ex`:

```elixir
defmodule Zenflows.Authz.Log do
@moduledoc """
Append-only trace of permission changes (`zf_permission_log`).  Each
entry is written in the same transaction as the change it records;
actor, service and request id always come from the context.
"""

alias Ecto.Multi
alias Zenflows.Authz.{ExecutionContext, PermissionLog}

@type entry() :: %{
	required(:action) => String.t(),
	required(:target_type) => String.t(),
	required(:target_id) => String.t(),
	optional(atom()) => term(),
}

@spec insert(Ecto.Repo.t(), ExecutionContext.t(), entry())
	:: {:ok, PermissionLog.t()} | {:error, Ecto.Changeset.t()}
def insert(repo, ctx, entry) do
	entry
	|> Map.merge(%{
		actor_id: ExecutionContext.actor_id(ctx),
		service: ctx.via,
		request_id: ctx.request_id,
	})
	|> PermissionLog.changeset()
	|> repo.insert()
end

@spec multi_insert(Multi.t(), term(), ExecutionContext.t(), (map() -> nil | entry()))
	:: Multi.t()
def multi_insert(m, key, ctx, entry_fun) do
	Multi.run(m, key, fn repo, changes ->
		case entry_fun.(changes) do
			nil -> {:ok, nil}
			entry -> insert(repo, ctx, entry)
		end
	end)
end
end
```

`src/zenflows/authz.ex`:

```elixir
defmodule Zenflows.Authz do
@moduledoc """
Authorization checks inside domain transactions.  Domain functions call
`multi_authorize/5` before writing; the decision itself is
`Zenflows.Authz.Policy`.
"""

require Logger

alias Ecto.Multi
alias Zenflows.Authz.{Config, ExecutionContext, Facts, Policy}

@spec authorize(ExecutionContext.t(), String.t(), Facts.t(), Config.opts())
	:: :ok | {:error, :forbidden | :unauthenticated}
def authorize(ctx, action, facts, opts \\ Config.opts()) do
	case Policy.authorize(ctx, action, facts, opts) do
		:ok -> :ok
		{:error, reason} = err ->
			enforced? = Keyword.get(opts, :enforce, true)
			report_deny(ctx, action, facts, reason, enforced?)
			if enforced?, do: err, else: :ok
	end
end

@doc "Load facts with `facts_fun`, decide, and abort the multi on deny."
@spec multi_authorize(Multi.t(), term(), ExecutionContext.t(), String.t(),
		(Ecto.Repo.t(), map() -> Facts.t())) :: Multi.t()
def multi_authorize(m, key, ctx, action, facts_fun) do
	Multi.run(m, key, fn repo, changes ->
		facts = facts_fun.(repo, changes)
		with :ok <- authorize(ctx, action, facts), do: {:ok, facts}
	end)
end

@doc "Put the authorized target under `key`, or fail with \"not found\"."
@spec multi_target(Multi.t(), term(), term()) :: Multi.t()
def multi_target(m, key, authz_key) do
	Multi.run(m, key, fn _repo, changes ->
		case Map.fetch!(changes, authz_key) do
			%Facts{target: nil} -> {:error, "not found"}
			%Facts{target: target} -> {:ok, target}
		end
	end)
end

defp report_deny(ctx, action, facts, reason, enforced?) do
	meta = %{
		actor_id: ExecutionContext.actor_id(ctx),
		action: action,
		target_id: target_id(facts),
		request_id: ctx.request_id,
		reason: reason,
		enforced: enforced?,
	}
	:telemetry.execute([:zenflows, :authz, :deny], %{count: 1}, meta)
	Logger.info("authz deny", Map.to_list(meta))
end

defp target_id(%Facts{target: %{id: id}}), do: id
defp target_id(_), do: nil
end
```

- [ ] **Step 7: Map errors**

In `src/zenflows/gql/mw/errors.ex`, add before `defp handle(error) do`:

```elixir
defp handle(:forbidden),
	do: [%{message: "forbidden", extensions: %{code: "FORBIDDEN"}}]

defp handle(:unauthenticated),
	do: [%{message: "unauthenticated", extensions: %{code: "UNAUTHENTICATED"}}]
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `./mann test test/authz/`
Expected: all authz tests pass.

- [ ] **Step 9: Commit**

```bash
git add src/zenflows/authz.ex src/zenflows/authz src/zenflows/gql/mw/errors.ex test/help/factory.ex test/authz/authz.test.exs
git commit -m "feat(authz): authorize inside multis, permission log, coded errors" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Controller on resource creation; context through events

**Files:**
- Create: `src/zenflows/authz/resource_control/domain.ex`
- Modify: `src/zenflows/vf/economic_resource/domain.ex:310-315` (`multi_insert/4`)
- Modify: `src/zenflows/vf/economic_event/domain.ex` (`create/3`, `create!/3`, `multi_insert/5`, every `handle_insert` clause)
- Modify: `src/zenflows/vf/economic_event/resolv.ex` (`create_economic_event/2`)
- Modify: `priv/repo/migrations/20251217151902_seed_material_resources.exs` (event call)
- Modify: `test/help/factory.ex` (`insert_economic_event!/0`)
- Modify (call sites): `test/vf/economic_event/domain.test.exs`, `test/vf/economic_event/track_and_trace.test.exs`, `test/file.test.exs`, `test/vf/economic_resource/track_and_trace.test.exs`, `test/vf/economic_resource/filter_scoping.test.exs`, `test/vf/economic_resource/geo_search.test.exs`, `test/vf/process/track_and_trace.test.exs`, `test/vf/proposal/filter_scoping.test.exs`
- Test: `test/authz/resource_control.test.exs`

**Interfaces:**
- Consumes: `Facts.admin_of/2`, `Log.multi_insert/4`, `Log.insert/3`, `ExecutionContext` (Tasks 2, 4).
- Produces:
  - `ResourceControl.Domain.one(repo \\ Repo, resource_id) :: {:ok, ResourceControl.t()} | {:error, "not found"}`
  - `ResourceControl.Domain.multi_on_create(multi, ctx, res_key) :: Multi.t()` (adds `"#{res_key}.control"` and `"#{res_key}.control.log"`)
  - `ResourceControl.Domain.controller_for(repo, ctx, resource) :: {agent_id, source}`
  - `EconomicResource.Domain.multi_insert(m, ctx, key \\ multi_key(), params)`
  - `EconomicEvent.Domain.create(%ExecutionContext{}, evt_params, res_params \\ nil)`, `create!/3`, `multi_insert(m, ctx, key \\ multi_key(), evt_params, res_params)`

- [ ] **Step 1: Write the failing test**

`test/authz/resource_control.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.ResourceControl do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Zenflows.Authz.{ExecutionContext, PermissionLog, ResourceControl}
alias Zenflows.VF.EconomicEvent

setup do
	%{
		alice: Factory.insert!(:person),
		bob: Factory.insert!(:person),
		carol: Factory.insert!(:person),
		org: Factory.insert!(:organization),
		unit: Factory.insert!(:unit),
		spec: Factory.insert!(:resource_specification),
	}
end

defp raise!(ctx, receiver_id, c) do
	EconomicEvent.Domain.create!(ctx, %{
		action_id: "raise",
		provider_id: receiver_id,
		receiver_id: receiver_id,
		resource_conforms_to_id: c.spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: Factory.str("res")})
end

defp control(evt), do: Repo.get_by!(ResourceControl, resource_id: evt.resource_inventoried_as_id)

defp logs(res_id) do
	Repo.all(from l in PermissionLog, where: l.target_id == ^res_id and l.action == "resource_control.set")
end

test "self-receiver: creator controls, one log row", c do
	evt = raise!(Factory.ctx(c.alice), c.alice.id, c)
	assert %ResourceControl{controller_id: id, source: :creation, epoch: 0} = control(evt)
	assert id == c.alice.id
	assert [%PermissionLog{actor_id: actor, service: :gql, subject_id: subject}] =
		logs(evt.resource_inventoried_as_id)
	assert actor == c.alice.id and subject == c.alice.id
end

test "foreign receiver: verified creator controls; declared receiver recorded", c do
	evt = raise!(Factory.ctx(c.bob), c.alice.id, c)
	assert control(evt).controller_id == c.bob.id
	assert [%PermissionLog{after: %{"declared_receiver_id" => declared}}] =
		logs(evt.resource_inventoried_as_id)
	assert declared == c.alice.id
end

test "org receiver: org controls when the creator is its admin", c do
	Factory.insert_admin!(c.alice, c.org)
	evt = raise!(Factory.ctx(c.alice), c.org.id, c)
	assert control(evt).controller_id == c.org.id
end

test "org receiver: creator controls when not an admin", c do
	evt = raise!(Factory.ctx(c.bob), c.org.id, c)
	assert control(evt).controller_id == c.bob.id
end

test "transfer to another agent: new resource controlled by the creator", c do
	evt = raise!(Factory.ctx(c.bob), c.bob.id, c)
	transfer = EconomicEvent.Domain.create!(Factory.ctx(c.bob), %{
		action_id: "transfer",
		provider_id: c.bob.id,
		receiver_id: c.carol.id,
		resource_inventoried_as_id: evt.resource_inventoried_as_id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: c.unit.id},
		has_point_in_time: Factory.now(),
	})
	assert %ResourceControl{controller_id: id} =
		Repo.get_by!(ResourceControl, resource_id: transfer.to_resource_inventoried_as_id)
	assert id == c.bob.id
end

test "migration context creates no control row", c do
	evt = raise!(ExecutionContext.service(:migration, nil), c.alice.id, c)
	assert Repo.get_by(ResourceControl, resource_id: evt.resource_inventoried_as_id) == nil
end

test "anonymous (unchecked) context: primary accountable controls", c do
	evt = raise!(Factory.ctx(), c.alice.id, c)
	assert %ResourceControl{controller_id: id, source: :creation} = control(evt)
	assert id == c.alice.id
end

test "create/3 rejects a missing context" do
	assert_raise FunctionClauseError, fn ->
		EconomicEvent.Domain.create(%{action_id: "raise"}, nil)
	end
end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./mann test test/authz/resource_control.test.exs`
Expected: failures (`EconomicEvent.Domain.create!/3` undefined or control row missing).

- [ ] **Step 3: Implement ResourceControl.Domain**

`src/zenflows/authz/resource_control/domain.ex`:

```elixir
defmodule Zenflows.Authz.ResourceControl.Domain do
@moduledoc "Reads of resource control, and its creation with each new resource."

alias Ecto.Multi
alias Zenflows.Authz.{ExecutionContext, Facts, Log, ResourceControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.{EconomicResource, Person}

@spec one(Ecto.Repo.t(), String.t()) :: {:ok, ResourceControl.t()} | {:error, String.t()}
def one(repo \\ Repo, resource_id) do
	case repo.get_by(ResourceControl, resource_id: resource_id) do
		nil -> {:error, "not found"}
		found -> {:ok, found}
	end
end

@doc """
Insert the control row (and its log entry) for the resource stored
under `res_key`.  Migration contexts are skipped: the backfill
migration covers resources created by earlier migrations.
"""
@spec multi_on_create(Multi.t(), ExecutionContext.t(), term()) :: Multi.t()
def multi_on_create(m, %ExecutionContext{principal: {:service, :migration, _}}, _res_key), do: m
def multi_on_create(m, ctx, res_key) do
	m
	|> Multi.run("#{res_key}.control", fn repo, changes ->
		%EconomicResource{} = res = Map.fetch!(changes, res_key)
		{controller_id, source} = controller_for(repo, ctx, res)
		%{resource_id: res.id, controller_id: controller_id, source: source}
		|> ResourceControl.changeset()
		|> repo.insert()
	end)
	|> Log.multi_insert("#{res_key}.control.log", ctx, fn changes ->
		control = Map.fetch!(changes, "#{res_key}.control")
		res = Map.fetch!(changes, res_key)
		%{
			action: "resource_control.set",
			target_type: "economic_resource",
			target_id: control.resource_id,
			subject_id: control.controller_id,
			after: %{
				controller_id: control.controller_id,
				source: control.source,
				declared_receiver_id: res.primary_accountable_id,
			},
		}
	end)
end

@doc """
Who controls a new resource: the verified creator, or the receiving
organization when the creator is its admin.  Never the declared
receiver alone (events are not authorized yet).
"""
@spec controller_for(Ecto.Repo.t(), ExecutionContext.t(), EconomicResource.t())
	:: {String.t(), ResourceControl.source()}
def controller_for(repo, %ExecutionContext{principal: %Person{id: pid}} = ctx, res) do
	receiver = res.primary_accountable_id
	cond do
		receiver == pid -> {pid, :creation}
		MapSet.member?(Facts.admin_of(repo, ctx), receiver) -> {receiver, :creation}
		true -> {pid, :creation}
	end
end
def controller_for(_repo, %ExecutionContext{principal: {:service, :import, _}}, res),
	do: {res.primary_accountable_id, :admin}
def controller_for(_repo, _ctx, res),
	do: {res.primary_accountable_id, :creation}
end
```

- [ ] **Step 4: Hook it into resource creation**

In `src/zenflows/vf/economic_resource/domain.ex` add
`alias Zenflows.Authz.{ExecutionContext, ResourceControl}` and replace
`multi_insert/3` with:

```elixir
@spec multi_insert(Multi.t(), ExecutionContext.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, ctx, key \\ multi_key(), params) do
	m
	|> Multi.insert(key, EconomicResource.changeset(params))
	|> File.Domain.multi_insert(key, :images, :economic_resource_id)
	|> ResourceControl.Domain.multi_on_create(ctx, key)
end
```

- [ ] **Step 5: Thread the context through events**

In `src/zenflows/vf/economic_event/domain.ex`:

1. Add `alias Zenflows.Authz.ExecutionContext`.
2. Replace `create/2` and `create!/2` with:

```elixir
@spec create(ExecutionContext.t(), Schema.params(), nil | Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, String.t() | Changeset.t()}
def create(%ExecutionContext{} = ctx, evt_params, res_params \\ nil) do
	key = multi_key()
	Multi.new()
	|> multi_insert(ctx, evt_params, res_params)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec create!(ExecutionContext.t(), Schema.params(), nil | Schema.params()) :: EconomicEvent.t()
def create!(ctx, evt_params, res_params \\ nil) do
	{:ok, value} = create(ctx, evt_params, res_params)
	value
end
```

3. Replace `multi_insert/4` with:

```elixir
@spec multi_insert(Multi.t(), ExecutionContext.t(), term(), Schema.params(), nil | Schema.params())
	:: Multi.t()
def multi_insert(m, ctx, key \\ multi_key(), evt_params, res_params) do
	m
	|> Multi.insert("#{key}.created", EconomicEvent.changeset(evt_params))
	|> Multi.merge(&handle_insert(ctx, key, Map.fetch!(&1, "#{key}.created"), res_params))
end
```

4. Add `ctx` to every `handle_insert` clause and to the resource inserts:

```bash
sed -i '' -E 's/^defp handle_insert\(key, /defp handle_insert(ctx, key, /' src/zenflows/vf/economic_event/domain.ex
sed -i '' -E 's/EconomicResource\.Domain\.multi_insert\("/EconomicResource.Domain.multi_insert(ctx, "/' src/zenflows/vf/economic_event/domain.ex
```

Also update the `@spec handle_insert(term(), EconomicEvent.t(), nil | Schema.params())`
line to `@spec handle_insert(ExecutionContext.t(), term(), EconomicEvent.t(), nil | Schema.params())`.
Then run `./mann mix compile` and rename `ctx` to `_ctx` in each clause the
compiler reports as "variable ctx is unused" (the lower/consume,
work/deliverService, use, cite, pickup, dropoff, accept and modify clauses).

- [ ] **Step 6: Resolver, seed migration, factory, call sites**

In `src/zenflows/vf/economic_event/resolv.ex` add
`alias Zenflows.Authz.ExecutionContext` and replace `create_economic_event/2`:

```elixir
def create_economic_event(%{event: evt_params} = params, res) do
	res_params = params[:new_inventoried_resource]
	ctx = ExecutionContext.from_resolution(res)
	with {:ok, evt} <- Domain.create(ctx, evt_params, res_params) do
		{:ok, %{economic_event: evt}}
	end
end
```

In `priv/repo/migrations/20251217151902_seed_material_resources.exs`, change
`EconomicEvent.Domain.create(%{` to
`EconomicEvent.Domain.create(Zenflows.Authz.ExecutionContext.service(:migration, nil), %{`.

In `test/help/factory.ex` `insert_economic_event!/0`, change
`Zenflows.VF.EconomicEvent.Domain.create!(%{` to
`Zenflows.VF.EconomicEvent.Domain.create!(ctx(), %{`.

Update test call sites:

```bash
sed -i '' -E 's/(^|[^.A-Za-z])Domain\.create(!?)\(/\1Domain.create\2(Factory.ctx(), /g' test/vf/economic_event/domain.test.exs test/vf/economic_event/track_and_trace.test.exs
sed -i '' -E 's/EconomicEvent\.Domain\.create(!?)\(/EconomicEvent.Domain.create\1(Factory.ctx(), /g' test/file.test.exs test/vf/economic_resource/track_and_trace.test.exs test/vf/economic_resource/filter_scoping.test.exs test/vf/economic_resource/geo_search.test.exs test/vf/process/track_and_trace.test.exs test/vf/proposal/filter_scoping.test.exs
grep -rn "EconomicEvent.Domain.create\|EconomicResource.Domain.multi_insert" src test priv | grep -v "ctx" 
```

Expected: the final `grep` prints nothing.

- [ ] **Step 7: Run tests to verify they pass**

Run: `./mann test test/authz/resource_control.test.exs`
Expected: 8 tests, 0 failures.

Run: `./mann test`
Expected: no failures beyond `_build/baseline.txt`.

- [ ] **Step 8: Commit**

```bash
git add -A src test priv
git commit -m "feat(authz): record resource controller on creation" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Enforce resource update/delete; `resourceControl` query

**Files:**
- Modify: `src/zenflows/vf/economic_resource/domain.ex` (`update/3`, `update!/3`, `delete/2`, `delete!/2`, `multi_update/5`, `multi_delete/4`)
- Modify: `src/zenflows/vf/economic_resource/resolv.ex` (`update_economic_resource/2`, `delete_economic_resource/2`)
- Modify: `src/zenflows/vf/economic_resource/type.ex` (meta on both mutations)
- Create: `src/zenflows/authz/type.ex`, `src/zenflows/authz/resolv.ex`
- Modify: `src/zenflows/gql/schema.ex` (`import_types Zenflows.Authz.Type`, `import_fields :query_authz`)
- Modify (call sites): `test/vf/economic_resource/domain.test.exs`, `test/file.test.exs`
- Test: `test/authz/economic_resource.test.exs`

**Interfaces:**
- Consumes: `Authz.multi_authorize/5`, `Authz.multi_target/3`, `Facts.for_resource/3`, `Log.multi_insert/4`.
- Produces: `EconomicResource.Domain.update(ctx, id, params)`,
  `delete(ctx, id)`; GraphQL `resourceControl(resourceId: ID!): ResourceControl`
  with `controller: Agent!`, `source: String!`, `epoch: Int!`;
  module `Zenflows.Authz.Type` with objects `:resource_control`,
  `:query_authz` (Task 8 adds `:mutation_authz`).

- [ ] **Step 1: Write the failing test**

`test/authz/economic_resource.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.EconomicResource do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query
import ZenflowsTest.Help.AbsinCase, only: [run!: 2]

alias Ecto.Changeset
alias Zenflows.Authz.{PermissionLog, ResourceControl}
alias Zenflows.VF.{EconomicEvent, EconomicResource}

setup do
	alice = Factory.insert!(:person)
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	evt = EconomicEvent.Domain.create!(Factory.ctx(alice), %{
		action_id: "raise",
		provider_id: alice.id,
		receiver_id: alice.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: "alice's"})
	%{alice: alice, bob: Factory.insert!(:person), res: EconomicResource.Domain.one!(evt.resource_inventoried_as_id)}
end

test "controller may update", %{alice: alice, res: res} do
	assert {:ok, %EconomicResource{name: "renamed"}} =
		EconomicResource.Domain.update(Factory.ctx(alice), res.id, %{name: "renamed"})
end

test "another person may not update or delete", %{bob: bob, res: res} do
	assert {:error, :forbidden} = EconomicResource.Domain.update(Factory.ctx(bob), res.id, %{name: "x"})
	assert {:error, :forbidden} = EconomicResource.Domain.delete(Factory.ctx(bob), res.id)
	assert EconomicResource.Domain.one!(res.id).name == "alice's"
end

test "admin of the controlling org may update; revoked admin may not", %{bob: bob, res: res} do
	org = Factory.insert!(:organization)
	Repo.update_all(from(c in ResourceControl, where: c.resource_id == ^res.id),
		set: [controller_id: org.id])
	rel = Factory.insert_admin!(bob, org)
	assert {:ok, _} = EconomicResource.Domain.update(Factory.ctx(bob), res.id, %{name: "org's"})

	rel |> Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update!()
	assert {:error, :forbidden} = EconomicResource.Domain.update(Factory.ctx(bob), res.id, %{name: "x"})
end

test "missing id: forbidden for persons, not found for unchecked anonymous", %{bob: bob} do
	assert {:error, :forbidden} = EconomicResource.Domain.update(Factory.ctx(bob), Factory.id(), %{name: "x"})
	assert {:error, "not found"} = EconomicResource.Domain.update(Factory.ctx(), Factory.id(), %{name: "x"})
end

test "no control row: even primaryAccountable is denied", %{alice: alice, res: res} do
	Repo.delete_all(from c in ResourceControl, where: c.resource_id == ^res.id)
	assert {:error, :forbidden} = EconomicResource.Domain.update(Factory.ctx(alice), res.id, %{name: "x"})
end

test "delete by controller removes control and logs it", %{alice: alice, res: res} do
	assert {:ok, _} = EconomicResource.Domain.delete(Factory.ctx(alice), res.id)
	assert Repo.get_by(ResourceControl, resource_id: res.id) == nil
	assert [%PermissionLog{actor_id: actor}] =
		Repo.all(from l in PermissionLog, where: l.target_id == ^res.id and l.action == "resource_control.remove")
	assert actor == alice.id
end

test "resourceControl query", %{alice: alice, res: res} do
	assert %{data: %{"resourceControl" => %{"controller" => %{"id" => id}, "source" => "creation", "epoch" => 0}}} =
		run!("""
			query ($id: ID!) {
				resourceControl(resourceId: $id) { controller { id } source epoch }
			}
		""", vars: %{"id" => res.id})
	assert id == alice.id
end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./mann test test/authz/economic_resource.test.exs`
Expected: failures (`update/3` undefined).

- [ ] **Step 3: Enforce in the domain**

In `src/zenflows/vf/economic_resource/domain.ex` extend the alias to
`alias Zenflows.Authz`, `alias Zenflows.Authz.{ExecutionContext, Facts, Log, ResourceControl}`
and replace `update/2`, `update!/2`, `delete/1`, `delete!/1`, `multi_update/4`,
`multi_delete/3` with:

```elixir
@spec update(ExecutionContext.t(), Schema.id(), Schema.params())
	:: {:ok, EconomicResource.t()} | {:error, atom() | String.t() | Changeset.t()}
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

@spec update!(ExecutionContext.t(), Schema.id(), Schema.params()) :: EconomicResource.t()
def update!(ctx, id, params) do
	{:ok, value} = update(ctx, id, params)
	value
end

@spec delete(ExecutionContext.t(), Schema.id())
	:: {:ok, EconomicResource.t()} | {:error, atom() | String.t() | Changeset.t()}
def delete(%ExecutionContext{} = ctx, id) do
	key = multi_key()
	Multi.new()
	|> multi_delete(ctx, id)
	|> Repo.transaction()
	|> case do
		{:ok, %{^key => value}} -> {:ok, value}
		{:error, _, reason, _} -> {:error, reason}
	end
end

@spec delete!(ExecutionContext.t(), Schema.id()) :: EconomicResource.t()
def delete!(ctx, id) do
	{:ok, value} = delete(ctx, id)
	value
end
```

```elixir
@spec multi_update(Multi.t(), ExecutionContext.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, ctx, key \\ multi_key(), id, params) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "resource.update",
		fn repo, _ -> Facts.for_resource(repo, ctx, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.update(key,
		&EconomicResource.changeset(Map.fetch!(&1, "#{key}.one"), params))
	|> File.Domain.multi_update(key, :images, :economic_resource_id)
end

@spec multi_delete(Multi.t(), ExecutionContext.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, ctx, key \\ multi_key(), id) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "resource.delete",
		fn repo, _ -> Facts.for_resource(repo, ctx, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
	|> Log.multi_insert("#{key}.control.log", ctx, fn changes ->
		case Map.fetch!(changes, "#{key}.authz") do
			%Facts{control: %ResourceControl{} = c} ->
				%{
					action: "resource_control.remove",
					target_type: "economic_resource",
					target_id: c.resource_id,
					subject_id: c.controller_id,
					before: %{controller_id: c.controller_id, source: c.source, epoch: c.epoch},
				}
			_ -> nil
		end
	end)
end
```

Keep any lines that followed the old `Multi.delete` in `multi_delete` (copy
them after the new `Multi.delete` line).

- [ ] **Step 4: Resolvers and meta**

In `src/zenflows/vf/economic_resource/resolv.ex` add
`alias Zenflows.Authz.ExecutionContext` and:

```elixir
def update_economic_resource(%{resource: %{id: id} = params}, res) do
	with {:ok, eco_res} <- Domain.update(ExecutionContext.from_resolution(res), id, params) do
		{:ok, %{economic_resource: eco_res}}
	end
end

def delete_economic_resource(%{id: id}, res) do
	with {:ok, _} <- Domain.delete(ExecutionContext.from_resolution(res), id) do
		{:ok, true}
	end
end
```

In `src/zenflows/vf/economic_resource/type.ex`, add `meta authz: "resource.update"`
as the first line inside `field :update_economic_resource` and
`meta authz: "resource.delete"` inside `field :delete_economic_resource`.

- [ ] **Step 5: `resourceControl` query**

`src/zenflows/authz/type.ex`:

```elixir
defmodule Zenflows.Authz.Type do
@moduledoc "GraphQL types of authorization."

use Absinthe.Schema.Notation

alias Zenflows.Authz.Resolv

@desc """
Administrative control of an economic resource.  Distinct from the
ValueFlows `primaryAccountable` and `custodian`.
"""
object :resource_control do
	@desc "The agent that may administer the resource."
	field :controller, non_null(:agent), resolve: &Resolv.controller/3

	@desc "How control was established: creation, backfill, transfer or admin."
	field :source, non_null(:string), resolve: &Resolv.source/3

	@desc "Incremented on every change of control."
	field :epoch, non_null(:integer)
end

object :query_authz do
	@desc "Who administratively controls the given economic resource."
	field :resource_control, :resource_control do
		meta only_guest?: true
		arg :resource_id, non_null(:id)
		resolve &Resolv.resource_control/2
	end
end
end
```

`src/zenflows/authz/resolv.ex`:

```elixir
defmodule Zenflows.Authz.Resolv do
@moduledoc false

alias Zenflows.Authz.ResourceControl
alias Zenflows.DB.Repo

def resource_control(%{resource_id: id}, _) do
	case ResourceControl.Domain.one(id) do
		{:ok, control} -> {:ok, control}
		{:error, _} -> {:ok, nil}
	end
end

def controller(control, _, _) do
	{:ok, Repo.preload(control, :controller).controller}
end

def source(control, _, _), do: {:ok, to_string(control.source)}
end
```

In `src/zenflows/gql/schema.ex` add `import_types Zenflows.Authz.Type` after
`import_types Zenflows.InstVars.Type`, and `import_fields :query_authz` after
`import_fields :query_inst_vars`.

- [ ] **Step 6: Update existing call sites**

```bash
sed -i '' -E 's/(^|[^.A-Za-z])Domain\.(update|delete)(!?)\(/\1Domain.\2\3(Factory.ctx(), /g' test/vf/economic_resource/domain.test.exs
sed -i '' -E 's/EconomicResource\.Domain\.(update|delete)(!?)\(/EconomicResource.Domain.\1\2(Factory.ctx(), /g' test/file.test.exs
```

- [ ] **Step 7: Run tests**

Run: `./mann test test/authz/economic_resource.test.exs`
Expected: 7 tests, 0 failures.

Run: `./mann test`
Expected: no failures beyond baseline.

- [ ] **Step 8: Commit**

```bash
git add -A src test
git commit -m "feat(authz): enforce resource update/delete, add resourceControl query" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Membership — relationships and roles

**Files:**
- Create: `src/zenflows/authz/membership.ex`
- Modify: `src/zenflows/vf/agent_relationship/domain.ex` (all write functions)
- Modify: `src/zenflows/vf/agent_relationship/resolv.ex`, `type.ex`
- Modify: `src/zenflows/vf/agent_relationship_role/domain.ex` (`update`, `delete`)
- Modify: `src/zenflows/vf/agent_relationship_role/resolv.ex`, `type.ex`
- Modify (call sites): `test/vf/agent_relationship/domain.test.exs`, `test/vf/agent_relationship_role/domain.test.exs`
- Test: `test/authz/membership.test.exs`

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces:
  - `Membership.multi_grant(multi, key, ctx, grant) :: Multi.t()` — authorizes `relationship.grant`
  - `Membership.multi_record_grant(multi, key, ctx, grant | (changes -> grant)) :: Multi.t()` — no authorization; allowlisted callers only
  - `Membership.multi_revoke(multi, key, ctx, %AgentRelationship{}, role_key) :: Multi.t()`
  - `Membership.check_deletable(repo, agent_id) :: {:ok, nil} | {:error, String.t()}`
  - `grant :: %{subject_id, object_id, role_key, optional note, optional reason}`
  - `AgentRelationship.Domain.create(ctx, params)`, `update(ctx, id, params)`, `delete(ctx, id)` (+ bang versions)
  - `AgentRelationshipRole.Domain.update(ctx, id, params)`, `delete(ctx, id)`
  - GraphQL: `AgentRelationship.inScopeOf: Agent`, `AgentRelationship.revokedAt: DateTime`, `AgentRelationshipRole.systemKey: String`

- [ ] **Step 1: Write the failing test**

`test/authz/membership.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Membership do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Zenflows.Authz.{PermissionLog, Roles}
alias Zenflows.VF.{AgentRelationship, AgentRelationshipRole}

setup do
	alice = Factory.insert!(:person)
	org = Factory.insert!(:organization)
	alice_rel = Factory.insert_admin!(alice, org)
	%{
		alice: alice, org: org, alice_rel: alice_rel,
		bob: Factory.insert!(:person),
		carol: Factory.insert!(:person),
		admin_role: Roles.id!(Repo, "org.admin"),
	}
end

defp grant(ctx, subject, c, params \\ %{}) do
	AgentRelationship.Domain.create(ctx, Map.merge(%{
		subject_id: subject.id, object_id: c.org.id, relationship_id: c.admin_role,
	}, params))
end

defp log_rows(action), do: Repo.all(from l in PermissionLog, where: l.action == ^action)

test "admin grants: scoped relationship and a log row", c do
	assert {:ok, %AgentRelationship{} = rel} = grant(Factory.ctx(c.alice), c.carol, c)
	assert rel.in_scope_of_id == c.org.id
	assert [%PermissionLog{actor_id: actor, subject_id: subject, role_key: "org.admin", target_id: tid}] =
		log_rows("relationship.grant")
	assert {actor, subject, tid} == {c.alice.id, c.carol.id, rel.id}
end

test "grant with string keys still goes through the grant path", c do
	assert {:error, :forbidden} = AgentRelationship.Domain.create(Factory.ctx(c.bob), %{
		"subject_id" => c.bob.id, "object_id" => c.org.id, "relationship_id" => c.admin_role,
	})
end

test "non-admin cannot grant; nothing written", c do
	assert {:error, :forbidden} = grant(Factory.ctx(c.bob), c.bob, c)
	assert log_rows("relationship.grant") == []
end

test "grant object must be an organization", c do
	assert {:error, "object must be an organization"} =
		grant(Factory.ctx(), c.carol, c, %{object_id: c.bob.id})
end

test "duplicate active grant is rejected; re-grant after revoke works", c do
	{:ok, rel} = grant(Factory.ctx(c.alice), c.carol, c)
	assert {:error, "already granted"} = grant(Factory.ctx(c.alice), c.carol, c)
	{:ok, _} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), rel.id)
	assert {:ok, %AgentRelationship{}} = grant(Factory.ctx(c.alice), c.carol, c)
end

test "revoke keeps the row, sets revoked_at, logs", c do
	{:ok, rel} = grant(Factory.ctx(c.alice), c.carol, c)
	assert {:ok, %AgentRelationship{revoked_at: %DateTime{}}} =
		AgentRelationship.Domain.delete(Factory.ctx(c.alice), rel.id)
	assert Repo.get!(AgentRelationship, rel.id).revoked_at
	assert [%PermissionLog{role_key: "org.admin"}] = log_rows("relationship.revoke")
	assert {:error, "already revoked"} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), rel.id)
end

test "the last admin cannot be revoked", c do
	assert {:error, :forbidden} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), c.alice_rel.id)
end

test "non-admin cannot revoke", c do
	{:ok, rel} = grant(Factory.ctx(c.alice), c.carol, c)
	assert {:error, :forbidden} = AgentRelationship.Domain.delete(Factory.ctx(c.bob), rel.id)
end

test "revoked admin cannot grant", c do
	{:ok, carol_rel} = grant(Factory.ctx(c.alice), c.carol, c)
	{:ok, _} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), carol_rel.id)
	assert {:error, :forbidden} = grant(Factory.ctx(c.carol), c.bob, c)
end

test "system relationship: note editable by admin, structure immutable", c do
	assert {:ok, %{note: "hi"}} =
		AgentRelationship.Domain.update(Factory.ctx(c.alice), c.alice_rel.id, %{note: "hi"})
	assert {:error, "system-role relationships can only change their note; revoke and grant instead"} =
		AgentRelationship.Domain.update(Factory.ctx(c.alice), c.alice_rel.id, %{subject_id: c.bob.id})
end

describe "non-system relationships" do
	setup c do
		role = Factory.insert!(:agent_relationship_role)
		%{role: role, bob_rel: AgentRelationship.Domain.create!(Factory.ctx(c.bob),
			%{subject_id: c.bob.id, object_id: c.carol.id, relationship_id: role.id})}
	end

	test "subject may create; others may not", c do
		assert {:error, :forbidden} = AgentRelationship.Domain.create(Factory.ctx(c.bob),
			%{subject_id: c.alice.id, object_id: c.carol.id, relationship_id: c.role.id})
	end

	test "others cannot update or delete", c do
		assert {:error, :forbidden} = AgentRelationship.Domain.update(Factory.ctx(c.alice), c.bob_rel.id, %{note: "x"})
		assert {:error, :forbidden} = AgentRelationship.Domain.delete(Factory.ctx(c.alice), c.bob_rel.id)
	end

	test "cannot switch to a system role", c do
		assert {:error, "use a grant to assign a system role"} =
			AgentRelationship.Domain.update(Factory.ctx(c.bob), c.bob_rel.id, %{relationship_id: c.admin_role})
	end

	test "subject may delete (hard delete, no log)", c do
		assert {:ok, _} = AgentRelationship.Domain.delete(Factory.ctx(c.bob), c.bob_rel.id)
		assert Repo.get(AgentRelationship, c.bob_rel.id) == nil
	end
end

test "system roles are immutable, even for unchecked anonymous", c do
	assert {:error, :forbidden} =
		AgentRelationshipRole.Domain.update(Factory.ctx(), c.admin_role, %{role_label: "x"})
	assert {:error, :forbidden} = AgentRelationshipRole.Domain.delete(Factory.ctx(), c.admin_role)
	role = Factory.insert!(:agent_relationship_role)
	assert {:ok, %{role_label: "y"}} =
		AgentRelationshipRole.Domain.update(Factory.ctx(c.bob), role.id, %{role_label: "y"})
end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./mann test test/authz/membership.test.exs`
Expected: failures (`AgentRelationship.Domain.create/2` with ctx undefined / wrong arity).

- [ ] **Step 3: Implement Membership**

`src/zenflows/authz/membership.ex`:

```elixir
defmodule Zenflows.Authz.Membership do
@moduledoc """
Organization roles as ValueFlows AgentRelationships with a system
AgentRelationshipRole (`org.admin`, `org.member`), scoped to the
organization through `in_scope_of`.  Every grant and revocation writes a
permission log entry; system-role relationships are revoked, never
deleted.
"""

import Ecto.Query

alias Ecto.{Changeset, Multi}
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, Log, ResourceControl, Roles}
alias Zenflows.VF.{AgentRelationship, Organization, Person}

@type grant() :: %{
	required(:subject_id) => String.t(),
	required(:object_id) => String.t(),
	required(:role_key) => String.t(),
	optional(:note) => nil | String.t(),
	optional(:reason) => nil | String.t(),
}

@doc "Authorize `relationship.grant`, then record the grant."
@spec multi_grant(Multi.t(), term(), ExecutionContext.t(), grant()) :: Multi.t()
def multi_grant(m, key, ctx, grant) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.grant", fn repo, _ ->
		%Facts{target: grant, role_key: grant.role_key, admin_of: Facts.admin_of(repo, ctx)}
	end)
	|> multi_record_grant(key, ctx, grant)
end

@doc """
Record a grant WITHOUT authorizing it.  Only for callers that already
authorized an action implying the grant (`organization.create`,
`organization.assign_admin`); see the allowlist in
test/authz/guard.test.exs.
"""
@spec multi_record_grant(Multi.t(), term(), ExecutionContext.t(), grant() | (map() -> grant()))
	:: Multi.t()
def multi_record_grant(m, key, ctx, grant_or_fun) do
	m
	|> Multi.run(key, fn repo, changes ->
		grant = resolve(grant_or_fun, changes)
		with :ok <- lock_org(repo, grant.object_id),
				:ok <- validate_grant(repo, grant),
				role_id = Roles.id!(repo, grant.role_key),
				:ok <- not_already_granted(repo, grant, role_id) do
			%AgentRelationship{}
			|> AgentRelationship.system_changeset(%{
				subject_id: grant.subject_id,
				object_id: grant.object_id,
				relationship_id: role_id,
				in_scope_of_id: grant.object_id,
				note: Map.get(grant, :note),
			})
			|> repo.insert()
		end
	end)
	|> Log.multi_insert("#{key}.log", ctx, fn changes ->
		grant = resolve(grant_or_fun, changes)
		rel = Map.fetch!(changes, key)
		%{
			action: "relationship.grant",
			target_type: "agent_relationship",
			target_id: rel.id,
			subject_id: rel.subject_id,
			role_key: grant.role_key,
			after: %{object_id: rel.object_id},
			reason: Map.get(grant, :reason),
		}
	end)
end

@doc "Authorize `relationship.revoke`, then set `revoked_at` and log."
@spec multi_revoke(Multi.t(), term(), ExecutionContext.t(), AgentRelationship.t(), String.t())
	:: Multi.t()
def multi_revoke(m, key, ctx, %AgentRelationship{} = rel, role_key) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.revoke", fn repo, _ ->
		:ok = lock_org(repo, rel.object_id)
		%Facts{
			target: rel,
			role_key: role_key,
			admin_of: Facts.admin_of(repo, ctx),
			active_admin_count: active_admin_count(repo, rel.object_id),
		}
	end)
	|> Multi.run(key, fn repo, _ ->
		if rel.revoked_at do
			{:error, "already revoked"}
		else
			rel |> Changeset.change(revoked_at: DateTime.utc_now()) |> repo.update()
		end
	end)
	|> Log.multi_insert("#{key}.log", ctx, fn changes ->
		revoked = Map.fetch!(changes, key)
		%{
			action: "relationship.revoke",
			target_type: "agent_relationship",
			target_id: revoked.id,
			subject_id: revoked.subject_id,
			role_key: role_key,
			before: %{revoked_at: nil},
			after: %{revoked_at: revoked.revoked_at},
		}
	end)
end

@doc "An agent with control or relationships cannot be hard-deleted."
@spec check_deletable(Ecto.Repo.t(), String.t()) :: {:ok, nil} | {:error, String.t()}
def check_deletable(repo, agent_id) do
	cond do
		repo.exists?(from c in ResourceControl, where: c.controller_id == ^agent_id) ->
			{:error, "agent controls resources; it cannot be deleted"}
		repo.exists?(from r in AgentRelationship,
				where: r.subject_id == ^agent_id or r.object_id == ^agent_id
					or r.in_scope_of_id == ^agent_id) ->
			{:error, "agent has relationships; it cannot be deleted"}
		true ->
			{:ok, nil}
	end
end

defp resolve(fun, changes) when is_function(fun, 1), do: fun.(changes)
defp resolve(grant, _changes), do: grant

# Serializes grants/revokes of one organization (last-admin and
# duplicate checks).
defp lock_org(repo, org_id) do
	repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", ["zf_org:" <> org_id])
	:ok
end

defp validate_grant(repo, grant) do
	cond do
		grant.role_key not in Roles.keys() ->
			{:error, "unknown system role"}
		not repo.exists?(from o in Organization, where: o.id == ^grant.object_id and o.type == :org) ->
			{:error, "object must be an organization"}
		not repo.exists?(from p in Person, where: p.id == ^grant.subject_id and p.type == :per) ->
			{:error, "subject must be a person"}
		true ->
			:ok
	end
end

defp not_already_granted(repo, grant, role_id) do
	if repo.exists?(from r in AgentRelationship,
			where: r.subject_id == ^grant.subject_id and r.object_id == ^grant.object_id
				and r.relationship_id == ^role_id and is_nil(r.revoked_at)),
		do: {:error, "already granted"},
		else: :ok
end

defp active_admin_count(repo, org_id) do
	admin_role = Roles.id!(repo, "org.admin")
	repo.aggregate(from(r in AgentRelationship,
		where: r.object_id == ^org_id and r.relationship_id == ^admin_role
			and is_nil(r.revoked_at)), :count)
end
end
```

- [ ] **Step 4: AgentRelationship domain**

In `src/zenflows/vf/agent_relationship/domain.ex`: add

```elixir
require Ecto.Query

alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, Membership, Roles}
```

Replace `create/1`, `create!/1`, `update/2`, `update!/2`, `delete/1`,
`delete!/1` so each takes `%ExecutionContext{} = ctx` as first argument and
calls `multi_insert(ctx, params)`, `multi_update(ctx, id, params)`,
`multi_delete(ctx, id)` (same body shape as Task 6's `update/3`), extend
`preload/2` to accept `:in_scope_of`, and replace the three multi functions
with:

```elixir
@spec multi_insert(Multi.t(), ExecutionContext.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, ctx, key \\ multi_key(), params) do
	m
	|> Multi.run("#{key}.role_key", fn repo, _ ->
		{:ok, Roles.key_of(repo, param(params, :relationship_id))}
	end)
	|> Multi.merge(fn changes ->
		case Map.fetch!(changes, "#{key}.role_key") do
			nil ->
				Multi.new()
				|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.create", fn repo, _ ->
					%Facts{target: %{subject_id: param(params, :subject_id)}, admin_of: Facts.admin_of(repo, ctx)}
				end)
				|> Multi.insert(key, AgentRelationship.changeset(params))
			role_key ->
				Membership.multi_grant(Multi.new(), key, ctx, %{
					subject_id: param(params, :subject_id),
					object_id: param(params, :object_id),
					role_key: role_key,
					note: param(params, :note),
				})
		end
	end)
end

@spec multi_update(Multi.t(), ExecutionContext.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, ctx, key \\ multi_key(), id, params) do
	m
	|> multi_load(key, id)
	|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.update", fn repo, changes ->
		%Facts{
			target: Map.fetch!(changes, "#{key}.one"),
			role_key: Map.fetch!(changes, "#{key}.role_key"),
			new_subject_id: param(params, :subject_id),
			admin_of: Facts.admin_of(repo, ctx),
		}
	end)
	|> Authz.multi_target("#{key}.target", "#{key}.authz")
	|> Multi.run("#{key}.checks", fn repo, changes ->
		validate_update(repo, Map.fetch!(changes, "#{key}.role_key"),
			Map.fetch!(changes, "#{key}.target"), params)
	end)
	|> Multi.update(key,
		&AgentRelationship.changeset(Map.fetch!(&1, "#{key}.target"), params))
end

@spec multi_delete(Multi.t(), ExecutionContext.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, ctx, key \\ multi_key(), id) do
	m
	|> multi_load(key, id)
	|> Multi.merge(fn changes ->
		rel = Map.fetch!(changes, "#{key}.one")
		case Map.fetch!(changes, "#{key}.role_key") do
			role_key when rel != nil and role_key != nil ->
				Membership.multi_revoke(Multi.new(), key, ctx, rel, role_key)
			_ ->
				Multi.new()
				|> Authz.multi_authorize("#{key}.authz", ctx, "relationship.delete", fn repo, _ ->
					%Facts{target: rel, admin_of: Facts.admin_of(repo, ctx)}
				end)
				|> Authz.multi_target("#{key}.target", "#{key}.authz")
				|> Multi.delete(key, &Map.fetch!(&1, "#{key}.target"))
		end
	end)
end

defp multi_load(m, key, id) do
	m
	|> Multi.run("#{key}.one", fn repo, _ ->
		{:ok, repo.one(Ecto.Query.from(r in AgentRelationship, where: r.id == ^id, lock: "FOR UPDATE"))}
	end)
	|> Multi.run("#{key}.role_key", fn repo, changes ->
		case Map.fetch!(changes, "#{key}.one") do
			nil -> {:ok, nil}
			rel -> {:ok, Roles.key_of(repo, rel.relationship_id)}
		end
	end)
end

@system_immutable ~w[subject_id object_id relationship_id]a

defp validate_update(repo, role_key, rel, params) do
	cond do
		role_key != nil and Enum.any?(@system_immutable, fn f ->
				v = param(params, f)
				v != nil and v != Map.fetch!(rel, f)
			end) ->
			{:error, "system-role relationships can only change their note; revoke and grant instead"}
		role_key == nil and Roles.key_of(repo, param(params, :relationship_id)) != nil ->
			{:error, "use a grant to assign a system role"}
		true ->
			{:ok, nil}
	end
end

defp param(params, key), do: Map.get(params, key, Map.get(params, Atom.to_string(key)))
```

Remove the now-unused `multi_one/3` only if nothing else calls it
(`grep -rn "AgentRelationship.Domain.multi_one" src test`).

- [ ] **Step 5: AgentRelationshipRole domain**

In `src/zenflows/vf/agent_relationship_role/domain.ex` add
`require Ecto.Query`, `alias Zenflows.Authz`,
`alias Zenflows.Authz.{ExecutionContext, Facts}`; make `update`, `update!`,
`delete`, `delete!` take `%ExecutionContext{} = ctx` first (same shape as
Task 6), and replace `multi_update/4`, `multi_delete/3` with:

```elixir
@spec multi_update(Multi.t(), ExecutionContext.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, ctx, key \\ multi_key(), id, params) do
	m
	|> multi_authorize_role(ctx, key, "role.update", id)
	|> Multi.update(key,
		&AgentRelationshipRole.changeset(Map.fetch!(&1, "#{key}.one"), params))
end

@spec multi_delete(Multi.t(), ExecutionContext.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, ctx, key \\ multi_key(), id) do
	m
	|> multi_authorize_role(ctx, key, "role.delete", id)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end

# System roles are immutable for every principal, including unchecked
# anonymous calls: the policy is not enough here.
defp multi_authorize_role(m, ctx, key, action, id) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, action, fn repo, _ ->
		%Facts{target: repo.one(Ecto.Query.from(r in AgentRelationshipRole,
			where: r.id == ^id, lock: "FOR UPDATE"))}
	end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.run("#{key}.system", fn _, changes ->
		case Map.fetch!(changes, "#{key}.one") do
			%AgentRelationshipRole{system_key: nil} -> {:ok, nil}
			%AgentRelationshipRole{} -> {:error, :forbidden}
		end
	end)
end
```

- [ ] **Step 6: Resolvers, types**

`src/zenflows/vf/agent_relationship/resolv.ex`: add
`alias Zenflows.Authz.ExecutionContext`; in `create_agent_relationship/2`,
`update_agent_relationship/2`, `delete_agent_relationship/2` rename the
second argument `_` to `res` and pass `ExecutionContext.from_resolution(res)`
as first argument of the `Domain` call. Add:

```elixir
def in_scope_of(%AgentRelationship{} = rel, _, _) do
	rel = Domain.preload(rel, :in_scope_of)
	{:ok, rel.in_scope_of}
end
```

`src/zenflows/vf/agent_relationship/type.ex`: replace the
`#field :in_scope_of, list_of(non_null(:accounting_scope))` line in
`object :agent_relationship` with:

```elixir
	@desc "The organization a system role is scoped to."
	field :in_scope_of, :agent, resolve: &Resolv.in_scope_of/3

	@desc "When a system-role relationship was revoked; null while active."
	field :revoked_at, :datetime
```

and add `meta authz: "relationship.create"`, `"relationship.update"`,
`"relationship.delete"` to the three mutation fields.

`src/zenflows/vf/agent_relationship_role/resolv.ex`: same context passing in
`update_agent_relationship_role/2` and `delete_agent_relationship_role/2`.
`src/zenflows/vf/agent_relationship_role/type.ex`: add to the role object

```elixir
	@desc "Stable key of a system role (e.g. org.admin); null for user-defined roles."
	field :system_key, :string
```

and `meta authz: "role.update"` / `"role.delete"` to the update/delete
mutation fields (leave `create_agent_relationship_role` unchanged).

- [ ] **Step 7: Existing call sites**

```bash
sed -i '' -E 's/(^|[^.A-Za-z])Domain\.(create|update|delete)(!?)\(/\1Domain.\2\3(Factory.ctx(), /g' test/vf/agent_relationship/domain.test.exs
sed -i '' -E 's/(^|[^.A-Za-z])Domain\.(update|delete)(!?)\(/\1Domain.\2\3(Factory.ctx(), /g' test/vf/agent_relationship_role/domain.test.exs
```

- [ ] **Step 8: Run tests**

Run: `./mann test test/authz/membership.test.exs`
Expected: all pass.

Run: `./mann test`
Expected: no failures beyond baseline.

- [ ] **Step 9: Commit**

```bash
git add -A src test
git commit -m "feat(authz): org roles as VF agent relationships with grant/revoke log" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Organizations — enforcement, creator admin, `assignOrganizationAdmin`

**Files:**
- Modify: `src/zenflows/vf/organization/domain.ex`
- Modify: `src/zenflows/vf/organization/resolv.ex`, `type.ex`
- Modify: `src/zenflows/authz/type.ex`, `src/zenflows/authz/resolv.ex` (mutation)
- Modify: `src/zenflows/gql/schema.ex` (`import_fields :mutation_authz`)
- Modify: `priv/repo/migrations/20251217151902_seed_material_resources.exs` (org call)
- Modify (call sites): `test/vf/organization/domain.test.exs`, `test/file.test.exs`, `test/vf/economic_resource/track_and_trace.test.exs`
- Test: `test/authz/organization.test.exs`

**Interfaces:**
- Consumes: `Membership.multi_record_grant/4`, `Membership.check_deletable/2`, `Facts.for_organization/3`.
- Produces: `Organization.Domain.create(ctx, params)`, `update(ctx, id, params)`,
  `delete(ctx, id)` (+ bangs), `assign_admin(ctx, org_id, person_id, reason) :: {:ok, AgentRelationship.t()} | {:error, term()}`;
  GraphQL `assignOrganizationAdmin(organizationId: ID!, personId: ID!, reason: String!): AgentRelationship!`.

- [ ] **Step 1: Write the failing test**

`test/authz/organization.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Organization do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query
import ZenflowsTest.Help.AbsinCase, only: [run!: 2]

alias Zenflows.Authz.{ExecutionContext, PermissionLog, Roles}
alias Zenflows.VF.{AgentRelationship, Organization}

setup do
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person)}
end

defp admin_ctx(),
	do: ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})

test "creator becomes admin, logged", %{alice: alice} do
	{:ok, org} = Organization.Domain.create(Factory.ctx(alice), %{name: Factory.str("org")})
	admin_role = Roles.id!(Repo, "org.admin")
	assert %AgentRelationship{in_scope_of_id: scope} =
		Repo.get_by!(AgentRelationship, subject_id: alice.id, object_id: org.id, relationship_id: admin_role)
	assert scope == org.id
	assert [%PermissionLog{reason: "organization creator"}] =
		Repo.all(from l in PermissionLog, where: l.action == "relationship.grant" and l.subject_id == ^alice.id)
end

test "admin may update; others may not", %{alice: alice, bob: bob} do
	{:ok, org} = Organization.Domain.create(Factory.ctx(alice), %{name: Factory.str("org")})
	assert {:ok, %Organization{name: "renamed"}} =
		Organization.Domain.update(Factory.ctx(alice), org.id, %{name: "renamed"})
	assert {:error, :forbidden} = Organization.Domain.update(Factory.ctx(bob), org.id, %{name: "x"})
	assert {:error, :forbidden} = Organization.Domain.delete(Factory.ctx(bob), org.id)
end

test "org with relationships cannot be deleted, even by its admin", %{alice: alice} do
	{:ok, org} = Organization.Domain.create(Factory.ctx(alice), %{name: Factory.str("org")})
	assert {:error, "agent has relationships; it cannot be deleted"} =
		Organization.Domain.delete(Factory.ctx(alice), org.id)
end

test "existing org without admin: forbidden until assigned", %{alice: alice} do
	org = Factory.insert!(:organization)
	assert {:error, :forbidden} = Organization.Domain.update(Factory.ctx(alice), org.id, %{name: "x"})

	assert {:ok, %AgentRelationship{}} =
		Organization.Domain.assign_admin(admin_ctx(), org.id, alice.id, "ticket #42")
	assert {:ok, _} = Organization.Domain.update(Factory.ctx(alice), org.id, %{name: "x"})
	assert [%PermissionLog{service: :admin_key, actor_id: nil, reason: "ticket #42"}] =
		Repo.all(from l in PermissionLog, where: l.action == "relationship.grant" and l.subject_id == ^alice.id)
end

test "assign_admin requires the admin key and a reason", %{alice: alice} do
	org = Factory.insert!(:organization)
	assert {:error, :forbidden} = Organization.Domain.assign_admin(Factory.ctx(alice), org.id, alice.id, "r")
	assert {:error, "reason is required"} = Organization.Domain.assign_admin(admin_ctx(), org.id, alice.id, " ")
end

test "assignOrganizationAdmin over GraphQL with the admin key", %{alice: alice} do
	org = Factory.insert!(:organization)
	key = Application.fetch_env!(:zenflows, Zenflows.Admin)[:admin_key] |> Base.encode16(case: :lower)
	assert %{data: %{"assignOrganizationAdmin" => %{"id" => _}}} =
		run!("""
			mutation ($org: ID!, $per: ID!) {
				assignOrganizationAdmin(organizationId: $org, personId: $per, reason: "ops") { id }
			}
		""", auth?: true, ctx: %{gql_admin: key}, vars: %{"org" => org.id, "per" => alice.id})
end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./mann test test/authz/organization.test.exs`
Expected: failures (`create/2` with ctx / `assign_admin/4` undefined).

- [ ] **Step 3: Organization domain**

In `src/zenflows/vf/organization/domain.ex` add:

```elixir
alias Zenflows.Authz
alias Zenflows.Authz.{ExecutionContext, Facts, Membership}
alias Zenflows.VF.{AgentRelationship, Person}
```

Make `create`, `create!`, `update`, `update!`, `delete`, `delete!` take
`%ExecutionContext{} = ctx` first (same shape as Task 6) and replace the
three multi functions:

```elixir
@spec multi_insert(Multi.t(), ExecutionContext.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, ctx, key \\ multi_key(), params) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "organization.create", fn _, _ -> %Facts{} end)
	|> Multi.insert(key, Organization.changeset(params))
	|> File.Domain.multi_insert(key, :images, :agent_id)
	|> multi_bootstrap_admin(ctx, key)
end

@spec multi_update(Multi.t(), ExecutionContext.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, ctx, key \\ multi_key(), id, params) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "organization.update",
		fn repo, _ -> Facts.for_organization(repo, ctx, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.update(key,
		&Organization.changeset(Map.fetch!(&1, "#{key}.one"), params))
	|> File.Domain.multi_update(key, :images, :agent_id)
end

@spec multi_delete(Multi.t(), ExecutionContext.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, ctx, key \\ multi_key(), id) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "organization.delete",
		fn repo, _ -> Facts.for_organization(repo, ctx, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.run("#{key}.deletable", fn repo, _ -> Membership.check_deletable(repo, id) end)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
end

@doc """
Make `person_id` an admin of an existing organization.  Admin key
only; the reason is stored in the permission log.
"""
@spec assign_admin(ExecutionContext.t(), Schema.id(), Schema.id(), String.t())
	:: {:ok, AgentRelationship.t()} | {:error, term()}
def assign_admin(%ExecutionContext{} = ctx, org_id, person_id, reason) do
	Multi.new()
	|> Authz.multi_authorize(:authz, ctx, "organization.assign_admin",
		fn repo, _ -> Facts.for_organization(repo, ctx, org_id) end)
	|> Authz.multi_target(:org, :authz)
	|> Multi.run(:reason, fn _, _ ->
		if is_binary(reason) and String.trim(reason) != "",
			do: {:ok, reason},
			else: {:error, "reason is required"}
	end)
	|> Membership.multi_record_grant(:admin, ctx, %{
		subject_id: person_id,
		object_id: org_id,
		role_key: "org.admin",
		reason: reason,
	})
	|> Repo.transaction()
	|> case do
		{:ok, %{admin: rel}} -> {:ok, rel}
		{:error, _, reason, _} -> {:error, reason}
	end
end

# The creator of an organization becomes its first admin, within the
# same transaction (authorized by `organization.create`).
defp multi_bootstrap_admin(m, %ExecutionContext{principal: %Person{id: pid}} = ctx, key) do
	Membership.multi_record_grant(m, "#{key}.admin", ctx, fn changes ->
		%{
			subject_id: pid,
			object_id: Map.fetch!(changes, key).id,
			role_key: "org.admin",
			reason: "organization creator",
		}
	end)
end
defp multi_bootstrap_admin(m, _ctx, _key), do: m
```

Delete `multi_one/3` if nothing else uses it.

- [ ] **Step 4: Resolvers, types, mutation**

`src/zenflows/vf/organization/resolv.ex`: add
`alias Zenflows.Authz.ExecutionContext`; pass
`ExecutionContext.from_resolution(res)` in create/update/delete (second
argument renamed `res`). `src/zenflows/vf/organization/type.ex`: add
`meta authz: "organization.create"`, `"organization.update"`,
`"organization.delete"`.

Append to `src/zenflows/authz/type.ex` (before the final `end`):

```elixir
object :mutation_authz do
	@desc """
	Make a person an admin of an existing organization.  Admin key only;
	always logged with the given reason.
	"""
	field :assign_organization_admin, non_null(:agent_relationship) do
		meta only_admin?: true, authz: "organization.assign_admin"
		arg :organization_id, non_null(:id)
		arg :person_id, non_null(:id)
		arg :reason, non_null(:string)
		resolve &Resolv.assign_organization_admin/2
	end
end
```

Append to `src/zenflows/authz/resolv.ex`:

```elixir
def assign_organization_admin(%{organization_id: org, person_id: per, reason: reason}, res) do
	Zenflows.VF.Organization.Domain.assign_admin(
		Zenflows.Authz.ExecutionContext.admin_key(res), org, per, reason)
end
```

In `src/zenflows/gql/schema.ex` add `import_fields :mutation_authz` after
`import_fields :mutation_keypairoom`.

In `priv/repo/migrations/20251217151902_seed_material_resources.exs` change
`Organization.Domain.create(%{` to
`Organization.Domain.create(Zenflows.Authz.ExecutionContext.service(:migration, nil), %{`.

- [ ] **Step 5: Existing call sites**

```bash
sed -i '' -E 's/(^|[^.A-Za-z])Domain\.(create|update|delete)(!?)\(/\1Domain.\2\3(Factory.ctx(), /g' test/vf/organization/domain.test.exs
sed -i '' -E 's/Organization\.Domain\.(create|update|delete)(!?)\(/Organization.Domain.\1\2(Factory.ctx(), /g' test/file.test.exs test/vf/economic_resource/track_and_trace.test.exs
```

- [ ] **Step 6: Run tests**

Run: `./mann test test/authz/organization.test.exs`
Expected: all pass.

Run: `./mann test`
Expected: no failures beyond baseline.

- [ ] **Step 7: Commit**

```bash
git add -A src test priv
git commit -m "feat(authz): enforce organizations, bootstrap creator admin, assignOrganizationAdmin" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Persons — self-only update, logged admin lifecycle

**Files:**
- Modify: `src/zenflows/vf/person/domain.ex`
- Modify: `src/zenflows/vf/person/resolv.ex`, `type.ex`
- Modify (call sites): `test/vf/person/domain.test.exs`, `test/file.test.exs`
- Test: `test/authz/person.test.exs`

**Interfaces:**
- Consumes: `Facts.for_person/2`, `Log.multi_insert/4`, `Membership.check_deletable/2`.
- Produces: `Person.Domain.create(ctx, params)`, `update(ctx, id, params)`,
  `delete(ctx, id)` (+ bangs).

- [ ] **Step 1: Write the failing test**

`test/authz/person.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Person do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Zenflows.Authz.{ExecutionContext, PermissionLog}
alias Zenflows.VF.Person

defp admin_ctx(),
	do: ExecutionContext.admin_key(%{context: %{authenticate_calls?: true, gql_admin: "k"}})

setup do
	%{alice: Factory.insert!(:person), bob: Factory.insert!(:person)}
end

test "self may update; others may not", %{alice: alice, bob: bob} do
	assert {:ok, %Person{name: "Alice"}} = Person.Domain.update(Factory.ctx(alice), alice.id, %{name: "Alice"})
	assert {:error, :forbidden} = Person.Domain.update(Factory.ctx(bob), alice.id, %{name: "x"})
end

test "persons cannot create or delete persons", %{alice: alice, bob: bob} do
	assert {:error, :forbidden} =
		Person.Domain.create(Factory.ctx(alice), %{name: "n", user: "u", email: "u@example.com"})
	assert {:error, :forbidden} = Person.Domain.delete(Factory.ctx(alice), bob.id)
end

test "admin key create/delete are logged" do
	{:ok, per} = Person.Domain.create(admin_ctx(), %{name: Factory.str("n"), user: Factory.str("u"), email: "#{Factory.str("u")}@example.com"})
	{:ok, _} = Person.Domain.delete(admin_ctx(), per.id)
	assert ["person.create", "person.delete"] ==
		Repo.all(from l in PermissionLog, where: l.target_id == ^per.id, select: l.action)
		|> Enum.sort()
end

test "person controlling resources cannot be deleted", %{alice: alice} do
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	Zenflows.VF.EconomicEvent.Domain.create!(Factory.ctx(alice), %{
		action_id: "raise", provider_id: alice.id, receiver_id: alice.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: "r"})
	assert {:error, "agent controls resources; it cannot be deleted"} =
		Person.Domain.delete(admin_ctx(), alice.id)
end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./mann test test/authz/person.test.exs`
Expected: failures.

- [ ] **Step 3: Person domain**

In `src/zenflows/vf/person/domain.ex` add
`alias Zenflows.Authz` and `alias Zenflows.Authz.{ExecutionContext, Facts, Log, Membership}`.
Make `create`, `create!`, `update`, `update!`, `delete`, `delete!` take
`%ExecutionContext{} = ctx` first; inside this module call
`__MODULE__.update(...)` (the module imports `Ecto.Query`). Replace the three
multi functions:

```elixir
@spec multi_insert(Multi.t(), ExecutionContext.t(), term(), Schema.params()) :: Multi.t()
def multi_insert(m, ctx, key \\ multi_key(), params) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "person.create", fn _, _ -> %Facts{} end)
	|> Multi.insert(key, Person.changeset(params))
	|> File.Domain.multi_insert(key, :images, :agent_id)
	|> Log.multi_insert("#{key}.log", ctx, fn changes ->
		%{action: "person.create", target_type: "person", target_id: Map.fetch!(changes, key).id}
	end)
end

@spec multi_update(Multi.t(), ExecutionContext.t(), term(), Schema.id(), Schema.params()) :: Multi.t()
def multi_update(m, ctx, key \\ multi_key(), id, params) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "person.update",
		fn repo, _ -> Facts.for_person(repo, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.update(key,
		&Person.changeset(Map.fetch!(&1, "#{key}.one"), params))
	|> File.Domain.multi_update(key, :images, :agent_id)
end

@spec multi_delete(Multi.t(), ExecutionContext.t(), term(), Schema.id()) :: Multi.t()
def multi_delete(m, ctx, key \\ multi_key(), id) do
	m
	|> Authz.multi_authorize("#{key}.authz", ctx, "person.delete",
		fn repo, _ -> Facts.for_person(repo, id) end)
	|> Authz.multi_target("#{key}.one", "#{key}.authz")
	|> Multi.run("#{key}.deletable", fn repo, _ -> Membership.check_deletable(repo, id) end)
	|> Multi.delete(key, &Map.fetch!(&1, "#{key}.one"))
	|> Log.multi_insert("#{key}.log", ctx, fn _ ->
		%{action: "person.delete", target_type: "person", target_id: id}
	end)
end
```

Keep `multi_one/3` (used by `claim/1`).

- [ ] **Step 4: Resolvers, types, call sites**

`src/zenflows/vf/person/resolv.ex`: add `alias Zenflows.Authz.ExecutionContext`;

```elixir
def create_person(%{person: params}, res) do
	with {:ok, per} <- Domain.create(ExecutionContext.admin_key(res), params) do
		{:ok, %{agent: per}}
	end
end

def update_person(%{person: %{id: id} = params}, res) do
	with {:ok, per} <- Domain.update(ExecutionContext.from_resolution(res), id, params) do
		{:ok, %{agent: per}}
	end
end

def delete_person(%{id: id}, res) do
	with {:ok, _} <- Domain.delete(ExecutionContext.admin_key(res), id) do
		{:ok, true}
	end
end
```

`src/zenflows/vf/person/type.ex`: `meta only_admin?: true, authz: "person.create"`
on `create_person`, `meta authz: "person.update"` on `update_person`,
`meta only_admin?: true, authz: "person.delete"` on `delete_person`
(replace the existing `meta only_admin?: true` lines).

```bash
sed -i '' -E 's/(^|[^.A-Za-z])Domain\.(create|update|delete)(!?)\(/\1Domain.\2\3(Factory.ctx(), /g' test/vf/person/domain.test.exs
sed -i '' -E 's/Person\.Domain\.(create|update|delete)(!?)\(/Person.Domain.\1\2(Factory.ctx(), /g' test/file.test.exs
```

- [ ] **Step 5: Run tests**

Run: `./mann test test/authz/person.test.exs test/vf/person`
Expected: all pass (the existing `createPerson`/`deletePerson` admin-key tests
still pass).

Run: `./mann test`
Expected: no failures beyond baseline.

- [ ] **Step 6: Commit**

```bash
git add -A src test
git commit -m "feat(authz): self-only person update, logged admin person lifecycle" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: SWPass import — service context and control rows

**Files:**
- Modify: `src/zenflows/sw_pass/domain.ex` (`import_repos/2`, new step)
- Modify: `src/zenflows/sw_pass/resolv.ex`, `type.ex`
- Modify: `src/zenflows/authz/resource_control/domain.ex` (`ensure_for_import/3`)
- Test: `test/authz/sw_pass.test.exs`

**Interfaces:**
- Consumes: `Authz.authorize/3`, `Log.insert/3`, `ExecutionContext.service/2`.
- Produces: `SWPass.Domain.import_repos(ctx, url)`,
  `ResourceControl.Domain.ensure_for_import(repo, ctx, resource) :: {:ok, ResourceControl.t()}`.

- [ ] **Step 1: Write the failing test**

`test/authz/sw_pass.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.SWPass do
use ZenflowsTest.Help.EctoCase, async: true

import Ecto.Query

alias Zenflows.Authz.{ExecutionContext, PermissionLog, ResourceControl}

test "ensure_for_import creates admin-sourced control once, logged as import" do
	res = Factory.insert!(:economic_resource)
	Repo.delete_all(from c in ResourceControl, where: c.resource_id == ^res.id)
	ctx = ExecutionContext.service(:import, "rid")

	assert {:ok, %ResourceControl{source: :admin, controller_id: cid}} =
		ResourceControl.Domain.ensure_for_import(Repo, ctx, res)
	assert cid == res.primary_accountable_id
	assert {:ok, _} = ResourceControl.Domain.ensure_for_import(Repo, ctx, res)
	assert [%PermissionLog{service: :import, request_id: "rid"}] =
		Repo.all(from l in PermissionLog,
			where: l.target_id == ^res.id and l.action == "resource_control.set" and l.service == :import)
end

test "import_repos refuses non-admin contexts before any HTTP call" do
	per = Factory.insert!(:person)
	assert {:error, :forbidden} =
		Zenflows.SWPass.Domain.import_repos(Factory.ctx(per), "http://127.0.0.1:1/never")
end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./mann test test/authz/sw_pass.test.exs`
Expected: failures (`ensure_for_import/3`, `import_repos/2` undefined).

- [ ] **Step 3: Implement**

Append to `src/zenflows/authz/resource_control/domain.ex`:

```elixir
@doc "Control for an imported resource; idempotent, logged on first insert."
@spec ensure_for_import(Ecto.Repo.t(), ExecutionContext.t(), EconomicResource.t())
	:: {:ok, ResourceControl.t()} | {:error, term()}
def ensure_for_import(repo, ctx, %EconomicResource{} = res) do
	case one(repo, res.id) do
		{:ok, control} -> {:ok, control}
		{:error, _} ->
			{controller_id, source} = controller_for(repo, ctx, res)
			with {:ok, control} <-
					%{resource_id: res.id, controller_id: controller_id, source: source}
					|> ResourceControl.changeset()
					|> repo.insert(),
				{:ok, _} <- Log.insert(repo, ctx, %{
					action: "resource_control.set",
					target_type: "economic_resource",
					target_id: res.id,
					subject_id: controller_id,
					after: %{controller_id: controller_id, source: source},
				}) do
				{:ok, control}
			end
	end
end
```

In `src/zenflows/sw_pass/domain.ex`: add
`alias Zenflows.Authz` and `alias Zenflows.Authz.{ExecutionContext, Facts, ResourceControl}`;
change the head to

```elixir
@spec import_repos(ExecutionContext.t(), String.t()) :: {:ok, term()} | {:error, term()}
def import_repos(%ExecutionContext{} = ctx, url) do
	with :ok <- Authz.authorize(ctx, "sw_pass.import", %Facts{}) do
		do_import_repos(ExecutionContext.service(:import, ctx.request_id), url)
	end
end

defp do_import_repos(import_ctx, url) do
```

(the old body becomes `do_import_repos/2`'s body), and add after the
`:update_produce_evt` step:

```elixir
			|> Multi.run(:resource_control, fn repo, %{resource: res} ->
				ResourceControl.Domain.ensure_for_import(repo, import_ctx, res)
			end)
```

`src/zenflows/sw_pass/resolv.ex`:

```elixir
def import_repos(%{url: url}, res) do
	case Domain.import_repos(Zenflows.Authz.ExecutionContext.admin_key(res), url) do
		{:ok, _} -> {:ok, "successfully imported"}
		{:error, reason} when reason in [:forbidden, :unauthenticated] -> {:error, reason}
		_ -> {:error, "something went wrong"}
	end
end
```

`src/zenflows/sw_pass/type.ex`: `meta only_admin?: true, authz: "sw_pass.import"`.

- [ ] **Step 4: Run tests**

Run: `./mann test test/authz/sw_pass.test.exs`
Expected: 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add -A src test
git commit -m "feat(authz): service context and control rows for SWPass import" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Backfill migration

**Files:**
- Create: `src/zenflows/authz/backfill.ex`
- Create: `priv/repo/migrations/20261001100001_backfill_zf_resource_control.exs`
- Test: `test/authz/backfill.test.exs`

**Interfaces:**
- Produces: `Zenflows.Authz.Backfill.run(repo) :: non_neg_integer()` (rows backfilled).

- [ ] **Step 1: Write the failing test**

`test/authz/backfill.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Backfill do
use ZenflowsTest.Help.EctoCase, async: false

import Ecto.Query

alias Zenflows.Authz.{Backfill, PermissionLog, ResourceControl}

test "trusts primaryAccountable, marks provenance, logs, is idempotent" do
	res = Factory.insert!(:economic_resource)
	Repo.delete_all(from c in ResourceControl, where: c.resource_id == ^res.id)

	assert Backfill.run(Repo) >= 1
	assert %ResourceControl{source: :backfill, controller_id: cid} =
		Repo.get_by!(ResourceControl, resource_id: res.id)
	assert cid == res.primary_accountable_id
	assert [%PermissionLog{service: :migration, actor_id: nil, after: %{"source" => "backfill"}}] =
		Repo.all(from l in PermissionLog, where: l.target_id == ^res.id and l.action == "resource_control.set" and l.service == :migration)

	assert Backfill.run(Repo) == 0
end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./mann test test/authz/backfill.test.exs`
Expected: compile error, `Zenflows.Authz.Backfill` not available.

- [ ] **Step 3: Implement**

`src/zenflows/authz/backfill.ex`:

```elixir
defmodule Zenflows.Authz.Backfill do
@moduledoc """
One-off backfill of `zf_resource_control` for resources created before
authorization existed.  Team decision: the existing `primaryAccountable`
is trusted as controller; `source = backfill` keeps it distinguishable.
Uses plain SQL so later schema changes don't break the migration.
"""

alias Zenflows.DB.ID

@batch 1000

@spec run(Ecto.Repo.t()) :: non_neg_integer()
def run(repo) do
	%{rows: rows} = repo.query!("""
		SELECT r.id, r.primary_accountable_id
		FROM vf_economic_resource r
		LEFT JOIN zf_resource_control c ON c.resource_id = r.id
		WHERE c.resource_id IS NULL AND r.primary_accountable_id IS NOT NULL
		""")
	now = DateTime.utc_now()

	rows
	|> Enum.chunk_every(@batch)
	|> Enum.each(fn chunk ->
		repo.insert_all("zf_resource_control", Enum.map(chunk, fn [res_id, pa_id] ->
			%{resource_id: res_id, controller_id: pa_id, source: "backfill", epoch: 0, updated_at: now}
		end))
		repo.insert_all("zf_permission_log", Enum.map(chunk, fn [res_id, pa_id] ->
			{:ok, id} = ID.dump(ID.gen())
			{:ok, controller} = ID.load(pa_id)
			%{
				id: id,
				service: "migration",
				action: "resource_control.set",
				target_type: "economic_resource",
				target_id: res_id,
				subject_id: pa_id,
				after: %{controller_id: controller, source: "backfill"},
				inserted_at: now,
			}
		end))
	end)

	length(rows)
end
end
```

`priv/repo/migrations/20261001100001_backfill_zf_resource_control.exs`:

```elixir
defmodule Zenflows.DB.Repo.Migrations.Backfill_zf_resource_control do
use Ecto.Migration

def up() do
	execute(fn -> Zenflows.Authz.Backfill.run(repo()) end)
end

def down() do
	# Log rows are append-only and stay; only the control rows go.
	execute "DELETE FROM zf_resource_control WHERE source = 'backfill'"
end
end
```

- [ ] **Step 4: Run tests**

Run: `./mann test test/authz/backfill.test.exs`
Expected: 1 test, 0 failures.

- [ ] **Step 5: Fresh-database migration (Review Focus 5)**

Run: `MIX_ENV=test ./mann mix ecto.drop && MIX_ENV=test ./mann mix ecto.create && MIX_ENV=test ./mann mix ecto.migrate`
Expected: all migrations run, no error. Then:
`docker exec zf-test-db psql -U zenflows -d zenflows_test -tAc "SELECT count(*) FROM vf_economic_resource r LEFT JOIN zf_resource_control c ON c.resource_id = r.id WHERE c.resource_id IS NULL"`
Expected: `0` (seeded resources got backfilled control).

Run: `MIX_ENV=test ./mann mix ecto.rollback --step 2 && MIX_ENV=test ./mann mix ecto.migrate`
Expected: both succeed (down migrations work).

- [ ] **Step 6: Commit**

```bash
git add src/zenflows/authz/backfill.ex priv/repo/migrations/20261001100001_backfill_zf_resource_control.exs test/authz/backfill.test.exs
git commit -m "feat(authz): backfill resource control from primaryAccountable" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Guards — mutation coverage and forbidden source patterns

**Files:**
- Test: `test/authz/guard.test.exs`

**Interfaces:**
- Consumes: `Policy.actions/0`, the Absinthe schema.

- [ ] **Step 1: Write the guard tests**

`test/authz/guard.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Guard do
use ExUnit.Case, async: true

alias Zenflows.Authz.Policy

# Mutations not covered by this slice: any valid signer, exactly as
# before.  Later slices shrink this list; adding to it needs review.
@pending ~w[
	echo
	create_product_batch update_product_batch delete_product_batch
	create_unit update_unit delete_unit
	create_recipe_process update_recipe_process delete_recipe_process
	create_role_behavior update_role_behavior delete_role_behavior
	create_recipe_exchange update_recipe_exchange delete_recipe_exchange
	create_process_specification update_process_specification delete_process_specification
	claim_person person_request_email_verification person_verify_email_verification
	create_plan update_plan delete_plan
	create_recipe_flow update_recipe_flow delete_recipe_flow
	create_spatial_thing update_spatial_thing delete_spatial_thing
	create_agreement update_agreement delete_agreement
	create_process_group update_process_group delete_process_group
	create_economic_event update_economic_event
	create_satisfaction update_satisfaction delete_satisfaction
	create_scenario update_scenario delete_scenario
	create_proposal update_proposal delete_proposal
	create_resource_specification update_resource_specification delete_resource_specification
	create_intent update_intent delete_intent
	create_agent_relationship_role
	create_recipe_resource update_recipe_resource delete_recipe_resource
	propose_intent delete_proposed_intent
	create_process update_process delete_process
	create_scenario_definition update_scenario_definition delete_scenario_definition
	keypairoom_server
]a

defp mutation_fields() do
	Absinthe.Schema.lookup_type(Zenflows.GQL.Schema, :mutation).fields
	|> Enum.reject(fn {id, _} -> String.starts_with?(Atom.to_string(id), "__") end)
end

test "every mutation declares a known authz action or is explicitly pending" do
	offenders =
		mutation_fields()
		|> Enum.map(fn {id, f} -> {id, Absinthe.Type.meta(f, :authz)} end)
		|> Enum.reject(fn
			{id, nil} -> id in @pending
			{_, action} when is_binary(action) -> action in Policy.actions()
			_ -> false
		end)
	assert offenders == []
end

test "pending list has no stale or already-covered entries" do
	fields = Map.new(mutation_fields())
	for id <- @pending do
		assert Map.has_key?(fields, id), "#{id} is no longer a mutation"
		assert Absinthe.Type.meta(fields[id], :authz) == nil, "#{id} is covered; remove it"
	end
end

defp sources() do
	Path.wildcard("src/**/*.ex") ++ Path.wildcard("priv/repo/migrations/*.exs")
end

defp offenders(pattern, allowed) do
	for path <- sources(), path not in allowed,
		{line, n} <- path |> File.read!() |> String.split("\n") |> Enum.with_index(1),
		Regex.match?(pattern, line),
		do: "#{path}:#{n}"
end

test "ExecutionContext is only built by its constructors" do
	assert offenders(~r/ExecutionContext\{.*request_id:/, []) == []
end

test "service contexts are only built by allowlisted callers" do
	assert offenders(~r/ExecutionContext\.service\(/, [
		"src/zenflows/sw_pass/domain.ex",
		"priv/repo/migrations/20251217151902_seed_material_resources.exs",
	]) == []
end

test "unauthorized grants are only recorded by allowlisted callers" do
	assert offenders(~r/multi_record_grant\(/, [
		"src/zenflows/authz/membership.ex",
		"src/zenflows/vf/organization/domain.ex",
	]) == []
end

test "resources are only inserted where control is recorded" do
	assert offenders(~r/EconomicResource\.changeset\(/, [
		"src/zenflows/vf/economic_resource/domain.ex",
		"src/zenflows/sw_pass/domain.ex",
	]) == []
end
end
```

- [ ] **Step 2: Run the guards**

Run: `./mann test test/authz/guard.test.exs`
Expected: 6 tests, 0 failures. If the coverage test lists an offender, either
add the right `meta authz:` (if this slice covers it) or add it to `@pending`
with a reason in the PR description.

- [ ] **Step 3: Prove the coverage guard bites**

Temporarily remove `meta authz: "resource.update"` from
`src/zenflows/vf/economic_resource/type.ex`, run the guard test, expect
`offenders == [update_economic_resource: nil]` failure, then restore the line.

- [ ] **Step 4: Commit**

```bash
git add test/authz/guard.test.exs
git commit -m "test(authz): guard mutation coverage and privileged call sites" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: API-level Alice/Bob tests and the revoke/update race

**Files:**
- Modify: `test/help/absin_case.ex` (`run_as!/3`)
- Test: `test/authz/api.test.exs`, `test/authz/concurrency.test.exs`

**Interfaces:**
- Produces: `AbsinCase.run_as!(person, doc, opts \\ [])` — runs with
  `authenticate_calls?: false` and `req_user: person` in the context (the
  same shape `MW.Sign` produces after verifying a signature).

- [ ] **Step 1: Add the helper**

In `test/help/absin_case.ex` add before the final `end`:

```elixir
@doc """
Run `doc` as `person`: puts `req_user` into the context exactly like
`MW.Sign` does after verifying a signature.  Signature checks are off.
"""
@spec run_as!(Zenflows.VF.Person.t(), String.t(), Keyword.t()) :: Absinthe.run_result()
def run_as!(person, doc, opts \\ []) do
	ctx = opts |> Keyword.get(:ctx, %{}) |> Map.put(:req_user, person)
	run!(doc, Keyword.put(opts, :ctx, ctx))
end
```

- [ ] **Step 2: Write the API tests**

`test/authz/api.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.API do
use ZenflowsTest.Help.AbsinCase, async: true

alias Zenflows.VF.{EconomicEvent, EconomicResource, Organization}

@forbidden %{message: "forbidden", extensions: %{code: "FORBIDDEN"}}

setup do
	alice = Factory.insert!(:person)
	unit = Factory.insert!(:unit)
	spec = Factory.insert!(:resource_specification)
	evt = EconomicEvent.Domain.create!(Factory.ctx(alice), %{
		action_id: "raise", provider_id: alice.id, receiver_id: alice.id,
		resource_conforms_to_id: spec.id,
		resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
		has_point_in_time: Factory.now(),
	}, %{name: "alice's"})
	%{alice: alice, bob: Factory.insert!(:person), res_id: evt.resource_inventoried_as_id}
end

test "Bob: updateEconomicResource is FORBIDDEN with data null", %{bob: bob, res_id: id} do
	assert %{data: nil, errors: [err]} =
		run_as!(bob, """
			mutation ($id: ID!) {
				updateEconomicResource(resource: {id: $id, name: "bob's"}) { economicResource { id } }
			}
		""", vars: %{"id" => id})
	assert Map.take(err, [:message, :extensions]) == @forbidden
	assert err.path == ["updateEconomicResource"]
	assert EconomicResource.Domain.one!(id).name == "alice's"
end

test "Bob: aliases and several root fields are each denied", %{bob: bob, res_id: id} do
	assert %{errors: errors} =
		run_as!(bob, """
			mutation ($id: ID!) {
				a: updateEconomicResource(resource: {id: $id, name: "x"}) { economicResource { id } }
				b: updateEconomicResource(resource: {id: $id, name: "y"}) { economicResource { id } }
				c: deleteEconomicResource(id: $id)
			}
		""", vars: %{"id" => id})
	assert length(errors) == 3
	assert Enum.all?(errors, &(Map.take(&1, [:message, :extensions]) == @forbidden))
	assert EconomicResource.Domain.one!(id).name == "alice's"
end

test "Alice: updateEconomicResource succeeds", %{alice: alice, res_id: id} do
	assert %{data: %{"updateEconomicResource" => %{"economicResource" => %{"id" => ^id}}}} =
		run_as!(alice, """
			mutation ($id: ID!) {
				updateEconomicResource(resource: {id: $id, name: "renamed"}) { economicResource { id } }
			}
		""", vars: %{"id" => id})
end

test "signed calls without headers are rejected before authz", %{res_id: id} do
	assert %{errors: [%{message: msg}]} =
		run!("""
			mutation ($id: ID!) { deleteEconomicResource(id: $id) }
		""", auth?: true, vars: %{"id" => id})
	assert msg =~ "zenflows-user"
end

test "Bob cannot update Alice's organization or Alice", %{alice: alice, bob: bob} do
	{:ok, org} = Organization.Domain.create(Factory.ctx(alice), %{name: Factory.str("org")})
	assert %{errors: [err1]} =
		run_as!(bob, """
			mutation ($id: ID!) { updateOrganization(organization: {id: $id, name: "x"}) { agent { id } } }
		""", vars: %{"id" => org.id})
	assert %{errors: [err2]} =
		run_as!(bob, """
			mutation ($id: ID!) { updatePerson(person: {id: $id, name: "x"}) { agent { id } } }
		""", vars: %{"id" => alice.id})
	assert Map.take(err1, [:message, :extensions]) == @forbidden
	assert Map.take(err2, [:message, :extensions]) == @forbidden
end

test "createOrganization makes the signer admin (visible over GraphQL)", %{bob: bob} do
	assert %{data: %{"createOrganization" => %{"agent" => %{"id" => org_id}}}} =
		run_as!(bob, """
			mutation { createOrganization(organization: {name: "#{Factory.str("org")}"}) { agent { id } } }
		""")
	assert %{data: %{"updateOrganization" => %{"agent" => %{"id" => ^org_id}}}} =
		run_as!(bob, """
			mutation ($id: ID!) { updateOrganization(organization: {id: $id, note: "mine"}) { agent { id } } }
		""", vars: %{"id" => org_id})
end
end
```

- [ ] **Step 3: Write the concurrency test**

`test/authz/concurrency.test.exs`:

```elixir
defmodule ZenflowsTest.Authz.Concurrency do
# Runs outside the SQL sandbox to get real concurrent transactions.
# async: false modules run alone, after all async modules.
use ExUnit.Case, async: false

import Ecto.Query, only: [from: 2]

alias Ecto.Adapters.SQL.Sandbox
alias Zenflows.Authz.{ExecutionContext, Roles}
alias Zenflows.DB.{ID, Repo}
alias Zenflows.VF.{AgentRelationship, Organization, Person}

defp ctx(per), do: ExecutionContext.from_resolution(%{context: %{req_user: per}})

defp person!() do
	s = ID.gen()
	Repo.insert!(Person.changeset(%{name: "p#{s}", user: "u#{s}", email: "#{s}@example.com"}))
end

setup do
	ids = Sandbox.unboxed_run(Repo, fn ->
		alice = person!()
		bob = person!()
		org = Repo.insert!(Organization.changeset(%Organization{}, %{name: "org#{ID.gen()}"}))
		role = Roles.id!(Repo, "org.admin")
		[alice_rel, bob_rel] =
			for per <- [alice, bob] do
				Repo.insert!(%AgentRelationship{subject_id: per.id, object_id: org.id,
					in_scope_of_id: org.id, relationship_id: role})
			end
		%{alice: alice, bob: bob, org: org, alice_rel: alice_rel, bob_rel: bob_rel}
	end)

	on_exit(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			Repo.delete_all(from r in AgentRelationship, where: r.object_id == ^ids.org.id)
			for a <- [ids.alice, ids.bob, ids.org], do: Repo.delete!(a)
			Repo.query!("TRUNCATE zf_permission_log")
		end)
	end)

	ids
end

test "update waiting on a concurrent revoke of the updater is denied", c do
	parent = self()

	revoker = Task.async(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			Repo.transaction(fn ->
				{:ok, _} = AgentRelationship.Domain.delete(ctx(c.bob), c.alice_rel.id)
				send(parent, :revoked_not_committed)
				receive do :commit -> :ok end
			end)
		end)
	end)
	assert_receive :revoked_not_committed, 5_000

	updater = Task.async(fn ->
		Sandbox.unboxed_run(Repo, fn ->
			Organization.Domain.update(ctx(c.alice), c.org.id, %{note: "late"})
		end)
	end)

	# The updater must be blocked on the revoked relationship row.
	assert Task.yield(updater, 300) == nil

	send(revoker.pid, :commit)
	assert {:ok, _} = Task.await(revoker)
	assert {:error, :forbidden} = Task.await(updater)
end
end
```

- [ ] **Step 4: Run tests**

Run: `./mann test test/authz/api.test.exs test/authz/concurrency.test.exs`
Expected: all pass. If the concurrency test fails with `Task.yield == {:ok, ...}`,
the facts loader is not taking the `FOR SHARE` lock — fix
`Facts.admin_of/2`, do not loosen the test.

- [ ] **Step 5: Commit**

```bash
git add test/help/absin_case.ex test/authz/api.test.exs test/authz/concurrency.test.exs
git commit -m "test(authz): Alice/Bob API negatives and revoke/update race" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Docs, config guide, release notes, final verification

**Files:**
- Modify: `docs/authz-foundation-design.md` (status, fold in "Spec deltas")
- Modify: `docs/configuration-guide.md` (two env vars)
- Modify: `conf/.env.templ` (two commented env vars)
- Create: `docs/authz-release-notes.md`

- [ ] **Step 1: Configuration docs**

Append to `docs/configuration-guide.md` (matching its bullet style):

```markdown
* `AUTHZ_ENFORCE`: Whether authorization denials are enforced.  The default
  is `true`.  `false` only logs denials (staging release gate); the server
  refuses to start in production with `false`.
* `AUTHZ_ALLOW_UNCHECKED`: Whether calls without a verified person (when
  `GQL_AUTH_CALLS=false`) may write.  The default is `true` in testing mode
  and `false` otherwise; the server refuses to start in production with
  `true`.
```

Append to `conf/.env.templ` after the `## gql` block:

```bash
## authz
#export AUTHZ_ENFORCE=true
#export AUTHZ_ALLOW_UNCHECKED=false
```

- [ ] **Step 2: Release notes**

`docs/authz-release-notes.md` (SPDX header, then):

```markdown
# Authorization foundation — release notes

**Status: CRUD enforced; events pending.**  `createEconomicEvent` can still
change quantity, custody, accountability or containment of another agent's
resource; that is the next slice.  Do not describe resources as generally
protected.

## Behaviour changes

- `updateEconomicResource`, `deleteEconomicResource`: resource controller, or
  an admin of the controlling organization.
- `createOrganization`: the signer becomes the organization's first admin.
  `updateOrganization`, `deleteOrganization`: organization admins only.
- `createAgentRelationship` with a system role (`org.admin`, `org.member`)
  is a grant: organization admins only.  Deleting such a relationship
  revokes it (`revokedAt`), it is never removed.  The last admin cannot be
  revoked.  Other relationships: their subject (or an admin of the subject
  organization).
- `updatePerson`: self only.
- System roles (`systemKey` not null) cannot be edited or deleted.
- Organizations/persons that control resources or take part in
  relationships cannot be hard-deleted.

## Errors

- `extensions.code: "FORBIDDEN"` (message `forbidden`) on denial, also for
  writes on IDs that do not exist.
- `extensions.code: "UNAUTHENTICATED"` for unsigned writes when signature
  checks are disabled and `AUTHZ_ALLOW_UNCHECKED=false`.

## New API

- `resourceControl(resourceId: ID!) { controller { id } source epoch }`
- `assignOrganizationAdmin(organizationId, personId, reason)` — admin key
  only, always logged.
- `AgentRelationship.inScopeOf`, `AgentRelationship.revokedAt`,
  `AgentRelationshipRole.systemKey`.
- Optional request header `zenflows-request-id` (`[A-Za-z0-9_-]{1,64}`),
  stored with permission log entries.

## Operations

- Migrations add `zf_resource_control` and the append-only
  `zf_permission_log`, seed the system roles, and backfill a controller for
  every existing resource from its `primaryAccountable` (`source: backfill`).
- **Existing organizations have no admin after the upgrade.**  Assign admins
  with `assignOrganizationAdmin` before users need to edit them.
- `assignOrganizationAdmin` widens the admin-key surface: review admin key
  handling before deploying.
- Rolling back the migrations drops the permission log.
```

- [ ] **Step 3: Update the spec**

In `docs/authz-foundation-design.md`: set **Status** to
`Implemented on feat/authz-foundation`, and add a section
`## 14. Deltas from the original draft` with the eight items from this plan's
"Spec deltas" section, verbatim. Also fix §3.3 (advisory lock instead of the
partial unique index) and §8 (pending mutations listed in the guard test).

- [ ] **Step 4: Final verification**

Run: `./mann test`
Expected: no failures beyond `_build/baseline.txt`; every `test/authz/*` test
passes.

Run: `./mann mix compile --force --warnings-as-errors`
Expected: no warnings.

Run: `git diff origin/master --stat`
Expected: only files listed in this plan.

- [ ] **Step 5: Commit**

```bash
git add docs conf/.env.templ
git commit -m "docs(authz): release notes, configuration and spec deltas" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
