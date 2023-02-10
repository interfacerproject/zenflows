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

defmodule Zenflows.VF.ProposedTo do
@moduledoc """
An agent to which the proposal is to be published.  A proposal can be
published to many agents.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema
alias Zenflows.VF.{Agent, Proposal}

@type t() :: %__MODULE__{
	proposed_to: Agent.t(),
	proposed: Proposal.t(),
}

schema "vf_proposed_to" do
	belongs_to :proposed_to, Agent
	belongs_to :proposed, Proposal
	timestamps()
end

@reqr ~w[proposed_to_id proposed_id]a
@cast @reqr

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.assoc_constraint(:proposed_to)
	|> Changeset.assoc_constraint(:proposed)
end
end
