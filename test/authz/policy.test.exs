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
