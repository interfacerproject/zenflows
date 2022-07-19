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

defmodule Zenflows.GQL.MW.Sign do
@moduledoc """
Absinthe middleware to verify GraphQL calls.
"""

@behaviour Absinthe.Middleware

alias Zenflows.Restroom
alias Zenflows.VF.Person

@impl true
def call(res, _opts) do
	# if this is admin-related call (such as createPerson and importRepos mutations),
	# skip it (since the `middleware/3` callback in # `Zenflows.GQL.Schema` is
	# called over and over.
	if match?(%{gql_admin: _}, res.context) do
		res
	else
		with %{gql_user: user, gql_sign: sign, gql_body: body} <- res.context,
				per when not is_nil(per) <- Person.Domain.by_user(user),
				true <- Restroom.verify_graphql?(body, sign, per.pubkeys) do
			res
		else _ ->
			Absinthe.Resolution.put_result(res, {:error, "you are not authenticated"})
		end
	end
end
end
