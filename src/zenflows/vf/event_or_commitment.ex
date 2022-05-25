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
