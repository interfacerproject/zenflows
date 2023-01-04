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

defmodule Zenflows.VF.ProposedIntent.Type do
@moduledoc false

use Absinthe.Schema.Notation

alias Zenflows.VF.ProposedIntent.Resolv

@desc """
Represents many-to-many relationships between Proposals and Intents,
supporting including intents in multiple proposals, as well as a proposal
including multiple intents.
"""
object :proposed_intent do
	field :id, non_null(:id)

	@desc """
	This is a reciprocal intent of this proposal, not primary.  Not meant
	to be used for intent matching.
	"""
	field :reciprocal, non_null(:boolean)

	@desc "The published proposal which this intent is part of."
	field :published_in, non_null(:proposal), resolve: &Resolv.published_in/3

	@desc "The intent which is part of this published proposal."
	field :publishes, non_null(:intent), resolve: &Resolv.publishes/3
end

object :proposed_intent_response do
	field :proposed_intent, non_null(:proposed_intent)
end

object :mutation_proposed_intent do
	@desc"""
	Include an existing intent as part of a proposal.
	@param publishedIn the (`Proposal`) to include the intent in
	@param publishes the (`Intent`) to include as part of the proposal
	"""
	field :propose_intent, non_null(:proposed_intent_response) do
		arg :published_in_id, non_null(:id), name: "published_in"
		arg :publishes_id, non_null(:id), name: "publishes"
		arg :reciprocal, :boolean
		resolve &Resolv.propose_intent/2
	end

	field :delete_proposed_intent, non_null(:boolean) do
		arg :id, non_null(:id)
		resolve &Resolv.delete_proposed_intent/2
	end
end
end
