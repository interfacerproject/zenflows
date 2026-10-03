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

defmodule Zenflows.Authz.ExecutionContext do
@moduledoc """
Who is acting, through which channel, for which request.

Build it only with the constructors below.  It is never built from
GraphQL arguments: the Person comes from `MW.Sign` (`req_user`), the
admin-key principal only from fields guarded by `MW.Admin`.
"""

alias Zenflows.DB.ID
alias Zenflows.VF.Person

@type service_name() :: :admin_key | :import | :migration
@type principal() ::
	Person.t()
	| {:service, service_name(), MapSet.t(String.t())}
	| :anonymous
@type via() :: :gql | :admin_key | :import | :migration
@type t() :: %__MODULE__{principal: principal(), via: via(), request_id: String.t()}

@enforce_keys [:principal, :via, :request_id]
defstruct @enforce_keys

@service_actions %{
	admin_key: ~w[person.create person.delete sw_pass.import organization.assign_admin object_control.assign],
	import: ~w[resource.create organization.create relationship.grant event.create],
	migration: ~w[resource.create organization.create resource_control.set event.create],
}

@doc "Context of a signed GraphQL field."
@spec from_resolution(%{context: map()}) :: t()
def from_resolution(%{context: c}) do
	principal =
		case c do
			%{req_user: %Person{} = per} -> per
			_ -> :anonymous
		end
	%__MODULE__{principal: principal, via: :gql, request_id: request_id(c)}
end

@doc """
Context of an `only_admin?` field.  Call only from resolvers of such
fields: the resolver runs only after `MW.Admin` accepted the key.
"""
@spec admin_key(%{context: map()}) :: t()
def admin_key(%{context: c}) do
	principal =
		if c[:authenticate_calls?] == true and is_binary(c[:gql_admin]),
			do: service_principal(:admin_key),
			else: :anonymous
	%__MODULE__{principal: principal, via: :admin_key, request_id: request_id(c)}
end

@doc "Context of import jobs and migrations.  Callers are allowlisted in tests."
@spec service(:import | :migration, nil | String.t()) :: t()
def service(name, request_id) when name in [:import, :migration] do
	%__MODULE__{
		principal: service_principal(name),
		via: name,
		request_id: request_id || ID.gen(),
	}
end

@doc "The acting Person's id, or nil for services and anonymous calls."
@spec actor_id(t()) :: nil | String.t()
def actor_id(%__MODULE__{principal: %Person{id: id}}), do: id
def actor_id(%__MODULE__{}), do: nil

defp service_principal(name),
	do: {:service, name, MapSet.new(Map.fetch!(@service_actions, name))}

defp request_id(%{request_id: rid}) when is_binary(rid), do: rid
defp request_id(_), do: ID.gen()
end
