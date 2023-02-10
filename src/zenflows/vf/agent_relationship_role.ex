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

defmodule Zenflows.VF.AgentRelationshipRole do
@moduledoc """
The role of an economic relationship that exists between two agents,
such as member, trading partner.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.RoleBehavior

@type t() :: %__MODULE__{
	role_behavior: RoleBehavior.t() | nil,
	role_label: String.t(),
	inverse_role_label: String.t() | nil,
	note: String.t() | nil,
}

schema "vf_agent_relationship_role" do
	belongs_to :role_behavior, RoleBehavior
	field :role_label, :string
	field :inverse_role_label, :string
	field :note, :string
	timestamps()
end

@reqr [:role_label]
@cast @reqr ++ ~w[role_behavior_id inverse_role_label note]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Validate.name(:role_label)
	|> Validate.name(:inverse_role_label)
	|> Validate.note(:note)
	|> Changeset.assoc_constraint(:role_behavior)
end
end
