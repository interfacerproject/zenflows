# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule ZenflowsTest.Authz.ResourceMetadata do
use ZenflowsTest.Help.EctoCase, async: true
import Ecto.Query
import ZenflowsTest.Help.AbsinCase, only: [run_as!: 3]
alias Ecto.Changeset
alias Zenflows.Authz.{PermissionLog, ResourceControl}
alias Zenflows.VF.{EconomicResource.Domain, EconomicResource.Metadata, EconomicEvent, Process}

setup do
	alice = Factory.insert!(:person)
	res = Factory.insert!(:economic_resource)
	Repo.update_all(from(c in ResourceControl, where: c.resource_id == ^res.id), set: [controller_id: alice.id])
	before = %{"opaque" => %{"private" => "not copied to audit"}, "contributors" => ["bob"], "relations" => ["old"]}
	res = res |> Changeset.change(metadata: before) |> Repo.update!()
	%{alice: alice, bob: Factory.insert!(:person), res: res}
end

defp logs(id), do: Repo.all(from l in PermissionLog, where: l.target_id == ^id and l.action == "resource.metadata.patch")

@mutation """
mutation Patch($id: ID!, $fields: JSONObject!, $expected: String) {
  patchEconomicResourceMetadata(resourceId: $id, fields: $fields, expectedMetadataHash: $expected) {
    economicResource { id metadata metadataHash }
  }
}
"""

test "controller patch preserves other keys and explicitly empty/null fields", c do
	assert {:ok, res} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"relations" => [], "nested" => nil})
	assert res.metadata == Map.merge(c.res.metadata, %{"relations" => [], "nested" => nil})
end

test "missing control and unrelated person denied; stale tokens cannot reveal content", c do
	for opts <- [[], [expected_metadata_hash: "stale"]] do
		assert {:error, :forbidden} = Domain.patch_metadata(Factory.ctx(c.bob), c.res.id, %{"relations" => []}, opts)
	end
	Repo.delete_all(from r in ResourceControl, where: r.resource_id == ^c.res.id)
	assert {:error, :forbidden} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"relations" => []})
	assert Domain.one!(c.res.id).metadata == c.res.metadata
	assert logs(c.res.id) == []
end

test "active org admin remains authorized, revoked admin denied", c do
	org = Factory.insert!(:organization)
	Repo.update_all(from(r in ResourceControl, where: r.resource_id == ^c.res.id), set: [controller_id: org.id])
	rel = Factory.insert_admin!(c.alice, org)
	assert {:ok, _} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"relations" => []})
	rel |> Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update!()
	assert {:error, :forbidden} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"relations" => ["late"]})
	assert Domain.one!(c.res.id).metadata["relations"] == []
end

test "compare-and-set stale content returns conflict without writes/audit", c do
	assert {:error, :conflict} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"relations" => []}, expected_metadata_hash: Metadata.hash(nil))
	assert Domain.one!(c.res.id) == c.res
	assert logs(c.res.id) == []
end

test "null, empty map and key ordering have defined fingerprints", c do
	assert Metadata.hash(%{"a" => %{"x" => 1, "y" => 2}, "b" => []}) == Metadata.hash(%{"b" => [], "a" => %{"y" => 2, "x" => 1}})
	assert Metadata.hash(nil) != Metadata.hash(%{})
	Repo.update!(Changeset.change(c.res, metadata: nil))
	assert {:ok, res} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"relations" => []}, expected_metadata_hash: Metadata.hash(nil))
	assert res.metadata == %{"relations" => []}
end

test "top-level patch replaces nested maps rather than recursively merging", c do
	assert {:ok, res} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"opaque" => %{"new" => true}})
	assert res.metadata["opaque"] == %{"new" => true}
	assert res.metadata["contributors"] == ["bob"]
end

test "empty patch is authorized but makes no change or log", c do
	assert {:ok, res} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{})
	assert res == c.res
	assert logs(c.res.id) == []
	assert {:error, :forbidden} = Domain.patch_metadata(Factory.ctx(c.bob), c.res.id, %{})
end

test "unchanged fields are also an authorized no-op", c do
	assert {:ok, res} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"relations" => ["old"]})
	assert res == c.res
	assert logs(c.res.id) == []
end

test "metadata-only edits do not manufacture processes/events or change custody/quantity/control", c do
	counts = {Repo.aggregate(EconomicEvent, :count), Repo.aggregate(Process, :count)}
	control = Repo.get_by!(ResourceControl, resource_id: c.res.id)
	assert {:ok, res} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"relations" => []})
	assert Map.drop(Map.from_struct(res), [:metadata, :updated_at]) == Map.drop(Map.from_struct(c.res), [:metadata, :updated_at])
	assert {Repo.aggregate(EconomicEvent, :count), Repo.aggregate(Process, :count)} == counts
	assert Repo.get_by!(ResourceControl, resource_id: res.id) == control
end

test "audit binds verified actor/service/request and records keys/digests, not raw content", c do
	ctx = %{Factory.ctx(c.alice) | request_id: "metadata-regression"}
	assert {:ok, res} = Domain.patch_metadata(ctx, c.res.id, %{"relations" => []})
	assert [%PermissionLog{} = log] = logs(res.id)
	assert log.actor_id == c.alice.id
	assert log.service == :gql
	assert log.request_id == "metadata-regression"
	assert log.before == %{"metadata_hash" => Metadata.hash(c.res.metadata)}
	assert log.after == %{"metadata_hash" => Metadata.hash(res.metadata), "fields" => ["relations"]}
	refute inspect(log) =~ "not copied to audit"
end

test "audit validation failure rolls back the metadata edit", c do
	ctx = %{Factory.ctx(c.alice) | request_id: %{invalid: :cast}}
	assert {:error, %Changeset{}} = Domain.patch_metadata(ctx, c.res.id, %{"relations" => []})
	assert Domain.one!(c.res.id) == c.res
	assert logs(c.res.id) == []
end

test "bad patch and precondition inputs produce safe errors without writes", c do
	for patch <- [nil, [], "{}", %{value: self()}] do
		assert {:error, :invalid_metadata_patch} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, patch)
	end
	assert {:error, :invalid_metadata_patch} = Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{}, expected_metadata_hash: nil)
	assert Domain.one!(c.res.id) == c.res
end

test "GraphQL invalid JSON roots reject without exceptions or writes", c do
	for fields <- ["null", "42", "true", ~s("text"), "[]", "{invalid"] do
		assert %{errors: [_ | _]} = run_as!(c.alice, @mutation, vars: %{"id" => c.res.id, "fields" => fields})
	end
	assert Domain.one!(c.res.id) == c.res
	assert logs(c.res.id) == []
end

test "GraphQL patch success and safe conflict code", c do
	vars = %{"id" => c.res.id, "fields" => Jason.encode!(%{"relations" => []}), "expected" => Metadata.hash(c.res.metadata)}
	assert %{data: %{"patchEconomicResourceMetadata" => %{"economicResource" => %{"metadata" => metadata, "metadataHash" => hash}}}} = run_as!(c.alice, @mutation, vars: vars)
	assert metadata == Map.put(c.res.metadata, "relations", [])
	assert hash == Metadata.hash(metadata)
	assert %{errors: [%{extensions: %{code: "CONFLICT"}}], data: nil} = run_as!(c.alice, @mutation, vars: vars)
end

test "GraphQL opaque keys cannot forge audit identity/control", c do
	fields = %{"actor_id" => c.bob.id, "controllerId" => c.bob.id}
	vars = %{"id" => c.res.id, "fields" => Jason.encode!(fields)}
	assert %{data: %{"patchEconomicResourceMetadata" => _}} = run_as!(c.alice, @mutation, vars: vars)
	assert Repo.get_by!(ResourceControl, resource_id: c.res.id).controller_id == c.alice.id
	assert [%PermissionLog{actor_id: actor}] = logs(c.res.id)
	assert actor == c.alice.id
	assert %{errors: [%{extensions: %{code: "FORBIDDEN"}}]} = run_as!(c.bob, @mutation, vars: vars)
end
end
