# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
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

@missing_headers_auth_call "couldn't aunthenticate: zenflows-user and/or zenflows-sign headers are missing"

@impl true
def call(res, _opts) do
	if res.context.authenticate_calls? do
		with {:ok, username, sign, body} <- fetch_ctx(res),
				{:ok, per} <- fetch_user(username),
				:ok <- verify_gql(body, sign, per) do
			put_in(res.context[:req_user], per)
		else x ->
			Absinthe.Resolution.put_result(res, x)
		end
	else
		res
	end
end

defp fetch_ctx(res) do
	case res.context do
		%{gql_user: username, gql_sign: sign, gql_body: body} ->
			{:ok, username, sign, body}
		_ -> {:error, @missing_headers_auth_call}
	end
end

defp fetch_user(username) do
	case Person.Domain.one(user: username) do
		{:ok, user} -> {:ok, user}
		_ -> {:error, "user not found"}
	end
end

defp verify_gql(body, sign, per) do
	case Restroom.verify_graphql(body, sign, per.eddsa_public_key) do
		:ok -> :ok
		{:error, reason} ->
			{:error,
			"""
			authentication error.

			details:

			#{reason}
			"""}
	end
end
end
