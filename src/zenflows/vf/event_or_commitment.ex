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
@spec chgset(Schema.t(), params()) :: Changeset.t()
def chgset(schema \\ %__MODULE__{}, params) do
	schema
	|> Changeset.cast(params, @cast)
	|> mutex_check()
	|> Changeset.assoc_constraint(:event)
	|> Changeset.assoc_constraint(:commitment)
end

# Validate mutual exclusivity of having either one of EconomicEvent
# or Commitment.
@spec mutex_check(Changeset.t()) :: Changeset.t()
defp mutex_check(cset) do
	# credo:disable-for-previous-line Credo.Check.Refactor.CyclomaticComplexity

	{data_evt, chng_evt} =
		case Changeset.fetch_field(cset, :event_id) do
			{:data, x} -> {x, nil}
			{:changes, x} -> {nil, x}
		end
	{data_comm, chng_comm} =
		case Changeset.fetch_field(cset, :commitment_id) do
			{:data, x} -> {x, nil}
			{:changes, x} -> {nil, x}
		end

	cond do
		data_evt && chng_comm ->
			msg = "commitment is not allowed in this record"
			Changeset.add_error(cset, :commitment_id, msg)

		data_comm && chng_evt ->
			msg = "event is not allowed in this record"
			Changeset.add_error(cset, :event_id, msg)

		chng_evt && chng_comm ->
			msg = "economic events and commitments are mutually exclusive"

			cset
			|> Changeset.add_error(:event_id, msg)
			|> Changeset.add_error(:commitment_id, msg)

		chng_evt || chng_comm ->
			cset

		true ->
			msg = "economic events or commitments is required"

			cset
			|> Changeset.add_error(:event_id, msg)
			|> Changeset.add_error(:commitment_id, msg)
	end
end
end
