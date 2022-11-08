# Zenflows is designed to implement the Valueflows vocabulary,
# written and maintained by srfsh <info@dyne.org>.
# Copyright (C) 2021-2022 Dyne.org foundation <foundation@dyne.org>.
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

defmodule Zenflows.VF.EventOrCommitment do
@moduledoc """
An EconomicEvent or Commitment, mutually exclusive.
"""

use Zenflows.DB.Schema

alias Ecto.Changeset
alias Zenflows.DB.{Schema, Validate}
alias Zenflows.VF.{Commitment, EconomicEvent}

@type t() :: %__MODULE__{
	event: EconomicEvent.t() | nil,
	commitment: Commitment.t() | nil,
}

schema "vf_event_or_commitment" do
	belongs_to :event, EconomicEvent
	belongs_to :commitment, Commitment
	timestamps()
end

@cast ~w[event_id commitment_id]a

@doc false
@spec changeset(Schema.t(), Schema.params()) :: Changeset.t()
def changeset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> Validate.exist_xor([:event_id, :commitment_id], method: :both)
	|> Changeset.assoc_constraint(:event)
	|> Changeset.assoc_constraint(:commitment)
end
end
