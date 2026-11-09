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

defmodule Zenflows.Authz.PermissionLog do
@moduledoc """
One append-only entry of `zf_permission_log`.  Write it only through
`Zenflows.Authz.Log`.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema

@type t() :: %__MODULE__{}

schema "zf_permission_log" do
	field :actor_id, Zenflows.DB.ID
	field :service, Ecto.Enum, values: [:gql, :admin_key, :import, :migration]
	field :action, :string
	field :target_type, :string
	field :target_id, Zenflows.DB.ID
	field :subject_id, Zenflows.DB.ID
	field :role_key, :string
	field :before, :map
	field :after, :map
	field :request_id, :string
	field :reason, :string
	field :inserted_at, :utc_datetime_usec, read_after_writes: true
end

@reqr ~w[service action target_type target_id]a
@cast @reqr ++ ~w[actor_id subject_id role_key before after request_id reason]a

@doc false
@spec changeset(Schema.params()) :: Changeset.t()
def changeset(params) do
	%__MODULE__{}
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
end
end
