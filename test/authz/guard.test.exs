# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

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

defp context_literal?(source) do
	Regex.match?(~r/ExecutionContext\{[\s\S]{0,400}?request_id:/, source)
end

test "context_literal?/1 detects multi-line and single-line literals but not pattern matches" do
	assert context_literal?("%ExecutionContext{\n\tprincipal: p,\n\tvia: :gql,\n\trequest_id: r,\n}")
	assert context_literal?("%ExecutionContext{principal: p, request_id: r}")
	refute context_literal?("def f(%ExecutionContext{principal: %Person{id: id}}), do: id")
end

test "ExecutionContext is only built by its constructors" do
	offenders =
		for path <- sources(), context_literal?(File.read!(path)), do: path
	assert offenders == []
end

test "service contexts are only built by allowlisted callers" do
	assert offenders(~r/ExecutionContext\.service\(/, [
		"src/zenflows/sw_pass/domain.ex",
		"priv/repo/migrations/20251217151902_seed_material_resources.exs",
	]) == []
end

test "admin-key contexts are only built by allowlisted resolvers" do
	assert offenders(~r/ExecutionContext\.admin_key\(/, [
		"src/zenflows/vf/person/resolv.ex",
		"src/zenflows/sw_pass/resolv.ex",
		"src/zenflows/authz/resolv.ex",
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
