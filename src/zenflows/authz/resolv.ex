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

defmodule Zenflows.Authz.Resolv do
@moduledoc false

alias Zenflows.Authz.{ExecutionContext, ObjectControl, ResourceControl}
alias Zenflows.DB.Repo

def resource_control(%{resource_id: id}, _) do
	case ResourceControl.Domain.one(id) do
		{:ok, control} -> {:ok, control}
		{:error, _} -> {:ok, nil}
	end
end

def object_control(%{target_type: type, target_id: id}, _) do
	case ObjectControl.Domain.one(type, id) do
		{:ok, control} -> {:ok, control}
		{:error, _} -> {:ok, nil}
	end
end

def controller(control, _, _) do
	{:ok, Repo.preload(control, :controller).controller}
end

def source(control, _, _), do: {:ok, to_string(control.source)}

def assign_organization_admin(%{organization_id: org, person_id: per, reason: reason}, res) do
	Zenflows.VF.Organization.Domain.assign_admin(
		ExecutionContext.admin_key(res), org, per, reason)
end

def assign_object_control(%{target_type: type, target_id: id, person_id: per, reason: reason}, res) do
	ObjectControl.Domain.assign(ExecutionContext.admin_key(res), type, id, per, reason)
end
end
