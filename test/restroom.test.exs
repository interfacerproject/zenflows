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

defmodule ZenflowsTest.Restroom do
use ExUnit.Case, async: true

import Zenflows.Restroom

describe "`byte_equal?/2" do
	test "returns `true` when the two matches" do
		assert byte_equal?("42", "42")
	end

	test "returns `false` when the two doesn't match" do
		refute byte_equal?("42", "41")
	end
end

describe "`hmac_new/2`, `hmac_verify/2`" do
	test "the hash is authentic" do
		data = Base.encode64("domates biber patlıcan")
		assert {:ok, hash} = hmac_new(data)
		assert :ok == hmac_verify(data, hash)
	end

	test "the hash is not authentic" do
		data_authentic = Base.encode64("domates biber patlıcan")
		data_forged = Base.encode64("domates biber patates")
		assert {:ok, hash} = hmac_new(data_authentic)
		assert {:error, _} = hmac_verify(data_forged, hash)
	end
end
end
