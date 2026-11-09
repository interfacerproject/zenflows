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

defmodule Zenflows.Authz.ResourceControl do
@moduledoc """
Administrative control of an EconomicResource.  Deliberately separate
from the ValueFlows `primaryAccountable`/`custodian` economic fields.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema
alias Zenflows.VF.{Agent, EconomicResource}

@type source() :: :creation | :backfill | :transfer | :admin
@type t() :: %__MODULE__{
	resource_id: Schema.id(),
	controller_id: Schema.id(),
	source: source(),
	epoch: non_neg_integer(),
}

@primary_key false
schema "zf_resource_control" do
	belongs_to :resource, EconomicResource, primary_key: true
	belongs_to :controller, Agent
	field :source, Ecto.Enum, values: [:creation, :backfill, :transfer, :admin]
	field :epoch, :integer, default: 0
	timestamps()
end

@reqr ~w[resource_id controller_id source]a
@cast @reqr ++ [:epoch]

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.assoc_constraint(:resource)
	|> Changeset.assoc_constraint(:controller)
	|> Changeset.unique_constraint(:resource_id, name: "zf_resource_control_pkey")
end
end
