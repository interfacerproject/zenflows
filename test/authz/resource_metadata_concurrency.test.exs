# SPDX-License-Identifier: AGPL-3.0-or-later
defmodule ZenflowsTest.Authz.ResourceMetadataConcurrency do
@moduledoc "Real separate PostgreSQL connections, not shared sandbox pseudo-concurrency."
use ExUnit.Case, async: false
import Ecto.Query
alias Ecto.Adapters.SQL.Sandbox
alias Zenflows.Authz.{PermissionLog, ResourceControl}
alias Zenflows.DB.Repo
alias Zenflows.VF.{EconomicEvent, EconomicResource, EconomicResource.Domain, EconomicResource.Metadata}
alias ZenflowsTest.Help.Factory

setup do
	fx = Sandbox.unboxed_run(Repo, fn ->
		alice = Factory.insert!(:person)
		bob = Factory.insert!(:person)
		unit = Factory.insert!(:unit)
		spec = Factory.insert!(:resource_specification)
		event = EconomicEvent.Domain.create!(Factory.ctx(alice), %{
			action_id: "raise", provider_id: alice.id, receiver_id: alice.id,
			resource_conforms_to_id: spec.id,
			resource_quantity: %{has_numerical_value: "1", has_unit_id: unit.id},
			has_point_in_time: Factory.now(), resource_metadata: %{"base" => true},
		}, %{name: "metadata race fixture"})
		%{alice: alice, bob: bob, unit: unit, spec: spec, event: event, res: Domain.one!(event.resource_inventoried_as_id)}
	end)
	on_exit(fn -> Sandbox.unboxed_run(Repo, fn ->
		Repo.update_all(from(e in EconomicEvent, where: e.id == ^fx.event.id), set: [resource_inventoried_as_id: nil])
		Repo.delete!(Repo.get!(EconomicResource, fx.res.id))
		Repo.delete!(fx.event)
		for row <- [fx.unit, fx.spec, fx.alice, fx.bob], do: Repo.delete!(row)
		Repo.query!("TRUNCATE zf_permission_log")
	end) end)
	fx
end

defp task(fun), do: Task.async(fn -> Sandbox.unboxed_run(Repo, fun) end)
defp parked(fun) do
	parent = self()
	task(fn ->
		{:ok, result} = Repo.transaction(fn ->
			result = fun.()
			send(parent, :locked)
			receive do :commit -> :ok after 10_000 -> Repo.rollback(:park_timeout) end
			result
		end)
		result
	end)
end

defp current(c), do: Sandbox.unboxed_run(Repo, fn -> Domain.one!(c.res.id) end)

test "independent fields merge from locked current row, not a stale pre-lock read", c do
	a = parked(fn -> Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"first" => 1}) end)
	try do
		assert_receive :locked, 2000
		b = task(fn -> Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"second" => 2}) end)
		assert Task.yield(b, 300) == nil
		send(a.pid, :commit)
		assert {:ok, _} = Task.await(a)
		assert {:ok, _} = Task.await(b)
		assert current(c).metadata == %{"base" => true, "first" => 1, "second" => 2}
	after
		send(a.pid, :commit)
	end
end

test "CAS rechecks after waiting: only one writer succeeds for the same snapshot", c do
	hash = Metadata.hash(c.res.metadata)
	a = parked(fn -> Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"choice" => "a"}, expected_metadata_hash: hash) end)
	try do
		assert_receive :locked, 2000
		b = task(fn -> Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"choice" => "b"}, expected_metadata_hash: hash) end)
		assert Task.yield(b, 300) == nil
		send(a.pid, :commit)
		assert {:ok, _} = Task.await(a)
		assert {:error, :conflict} = Task.await(b)
		assert current(c).metadata == %{"base" => true, "choice" => "a"}
		assert Sandbox.unboxed_run(Repo, fn -> Repo.aggregate(from(l in PermissionLog, where: l.target_id == ^c.res.id and l.action == "resource.metadata.patch"), :count) end) == 1
	after
		send(a.pid, :commit)
	end
end

test "a legacy full replacement also serializes against patch without erasing its new keys", c do
	a = parked(fn -> Domain.update(Factory.ctx(c.alice), c.res.id, %{metadata: %{"replacement" => true}}) end)
	try do
		assert_receive :locked, 2000
		b = task(fn -> Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"patch" => true}) end)
		assert Task.yield(b, 300) == nil
		send(a.pid, :commit)
		assert {:ok, _} = Task.await(a)
		assert {:ok, _} = Task.await(b)
		assert current(c).metadata == %{"replacement" => true, "patch" => true}
	after
		send(a.pid, :commit)
	end
end

test "control changed while patch waits is re-authorized before mutation", c do
	a = parked(fn -> Repo.update_all(from(r in ResourceControl, where: r.resource_id == ^c.res.id), set: [controller_id: c.bob.id]) end)
	try do
		assert_receive :locked, 2000
		b = task(fn -> Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"late" => true}) end)
		assert Task.yield(b, 300) == nil
		send(a.pid, :commit)
		Task.await(a)
		assert {:error, :forbidden} = Task.await(b)
		assert current(c).metadata == c.res.metadata
	after
		send(a.pid, :commit)
	end
end

test "unsynchronized patches on separate connections retain every independent field", c do
	for i <- 1..10 do
		a = task(fn -> Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"a#{i}" => i}) end)
		b = task(fn -> Domain.patch_metadata(Factory.ctx(c.alice), c.res.id, %{"b#{i}" => i}) end)
		assert {:ok, _} = Task.await(a)
		assert {:ok, _} = Task.await(b)
	end
	metadata = current(c).metadata
	assert metadata["base"] == true
	assert map_size(metadata) == 21
	for i <- 1..10, do: assert(metadata["a#{i}"] == i and metadata["b#{i}"] == i)
end
end
