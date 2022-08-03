# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule Zenflows.GQL.MW.Admin do
@moduledoc """
Absinthe middleware to authenticate administrative calls.
"""

@behaviour Absinthe.Middleware

alias Zenflows.Restroom

@impl true
def call(res, _opts) do
	if res.context.authenticate_calls? do
		with %{gql_admin: key} <- res.context,
				{:ok, key_given} <- Base.decode16(key, case: :lower),
				key_want = Application.fetch_env!(:zenflows, Zenflows.Admin)[:admin_key],
				true <- Restroom.byte_equal?(key_given, key_want) do
			res
		else _ ->
			Absinthe.Resolution.put_result(res, {:error, "you are not an admin"})
		end
	else
		res
	end
end
end
