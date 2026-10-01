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
end
