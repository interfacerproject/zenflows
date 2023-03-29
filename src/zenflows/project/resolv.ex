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

defmodule Zenflows.Project.Resolv do
@moduledoc false

alias Zenflows.Project.Domain

def project_create(%{project: params}, %{context: %{req_user: user}}) do
	params
	|> Map.put(:owner_id, user.id)
	|> Domain.create()
end

def project_add_contributor(%{contributor: params}, %{context: %{req_user: user}}) do
	params
	|> Map.put(:owner_id, user.id)
	|> Domain.add_contributor()
end

def project_fork(%{fork: params}, %{context: %{req_user: user}}) do
	params
	|> Map.put(:owner_id, user.id)
	|> Domain.fork()
end

def project_cite(%{cite: params}, %{context: %{req_user: user}}) do
	params
	|> Map.put(:owner_id, user.id)
	|> Domain.cite()
end
def project_cite(%{proposal_id: proposal_id}, %{context: %{req_user: user}}) do
	%{proposal_id: proposal_id, owner_id: user.id}
	|> Domain.approve()
end
end
