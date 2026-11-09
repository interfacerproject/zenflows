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

defmodule Zenflows.Authz.Type do
@moduledoc "GraphQL types of authorization."

use Absinthe.Schema.Notation

alias Zenflows.Authz.Resolv

@desc """
Administrative control of an economic resource.  Distinct from the
ValueFlows `primaryAccountable` and `custodian`.
"""
object :resource_control do
	@desc "The agent that may administer the resource."
	field :controller, non_null(:agent), resolve: &Resolv.controller/3

	@desc "How control was established: creation, backfill, transfer or admin."
	field :source, non_null(:string), resolve: &Resolv.source/3

	@desc "Incremented on every change of control."
	field :epoch, non_null(:integer)
end

object :query_authz do
	@desc "Who administratively controls the given economic resource."
	field :resource_control, :resource_control do
		meta only_guest?: true
		arg :resource_id, non_null(:id)
		resolve &Resolv.resource_control/2
	end
end

object :mutation_authz do
	@desc """
	Make a person an admin of an existing organization.  Admin key only;
	always logged with the given reason.
	"""
	field :assign_organization_admin, non_null(:agent_relationship) do
		meta only_admin?: true, authz: "organization.assign_admin"
		arg :organization_id, non_null(:id)
		arg :person_id, non_null(:id)
		arg :reason, non_null(:string)
		resolve &Resolv.assign_organization_admin/2
	end
end
end
