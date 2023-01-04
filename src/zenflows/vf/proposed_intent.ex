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

defmodule Zenflows.VF.ProposedIntent do
@moduledoc """
Represents many-to-many relationships between proposals and intents,
supporting including intents in multiple proposals, as well as a proposal
including multiple intents.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.Schema
alias Zenflows.VF.{Intent, Proposal}

@type t() :: %__MODULE__{
	reciprocal: boolean(),
	publishes: Intent.t(),
	published_in: Proposal.t(),
}

schema "vf_proposed_intent" do
	field :reciprocal, :boolean, default: false
	belongs_to :publishes, Intent
	belongs_to :published_in, Proposal
	timestamps()
end

@reqr ~w[publishes_id published_in_id]a
@cast @reqr ++ [:reciprocal]

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Changeset.validate_required(@reqr)
	|> Changeset.assoc_constraint(:publishes)
	|> Changeset.assoc_constraint(:published_in)
end
end
