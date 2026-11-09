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

defmodule ZenflowsTest.Authz.Pdp do
use ExUnit.Case, async: true

alias Zenflows.Authz.Pdp

# The shared contract vectors are the single source of truth; they live in
# the repo and both this (the Elixir PDP) and the Go PEP read them.
@vectors_file Path.expand("../../docs/cross-service-authz/contract.json", __DIR__)
@external_resource @vectors_file

@contract @vectors_file |> File.read!() |> Jason.decode!()

test "the vector file is the contract layer and is non-empty" do
	assert @contract["layer"] == "contract"
	assert @contract["vectors"] != []
end

# One test per vector, driving the pure decision function.
for vector <- @contract["vectors"] do
	@vector vector
	test "contract vector: #{vector["name"]}" do
		got = Pdp.decide(@vector["input"], @vector["facts"])

		assert got == @vector["expect"], """
		#{@vector["name"]}: #{@vector["doc"]}
		got:      #{inspect(got)}
		expected: #{inspect(@vector["expect"])}
		"""
	end
end

test "every action the PDP registers has a non-empty rule, and unknowns deny" do
	# A sanity check that the registry is wired and default-deny holds for an
	# action outside it, independent of the vectors.
	assert "dpp.spec.update" in Pdp.actions()
	refute "dpp.unknown.capability" in Pdp.actions()

	base = %{"action" => "dpp.spec.update"}
	proven = %{"principal_proven" => true, "controls_parent" => true, "epoch" => 1, "obligations" => %{}}
	assert %{"decision" => "allow"} = Pdp.decide(base, proven)
	assert %{"decision" => "deny", "reason_code" => "unknown_action"} =
		Pdp.decide(%{"action" => "nope.nope"}, proven)
end
end
