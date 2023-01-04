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

defmodule Zenflows.VF.Action do
@moduledoc """
An action verb defining the kind of event, commitment, or intent.
"""
use Ecto.Schema

alias Zenflows.VF.Action.ID

@type t() :: %__MODULE__{
	id: ID.t(),
	label: String.t(),
	resource_effect: String.t(),
	onhand_effect: String.t(),
	input_output: String.t(),
	pairs_with: String.t(),
}

@primary_key {:id, ID, []}
embedded_schema do
	field :label, :string
	field :resource_effect, :string
	field :onhand_effect, :string
	field :input_output, :string
	field :pairs_with, :string
end

@doc "Preloads the Action struct by the given `key`."
@spec preload(Ecto.Schema.t(), atom()) :: nil | Ecto.Schema.t()
def preload(schema, key) do
	%{schema | key => Map.get(map(), Map.fetch!(schema, :"#{key}_id"))}
end

@doc """
Returns a map, where each string ID key points to its corresponding
Action struct.
"""
@spec map() :: %{ID.t() => t()}
def map() do
	%{
		"produce" => %__MODULE__{
			id: "produce",
			label: "produce",
			resource_effect: "increment",
			onhand_effect: "increment",
			input_output: "output",
			pairs_with: "notApplicable",
		},
		"use" => %__MODULE__{
			id: "use",
			label: "use",
			resource_effect: "noEffect",
			onhand_effect: "noEffect",
			input_output: "input",
			pairs_with: "notApplicable",
		},
		"consume" => %__MODULE__{
			id: "consume",
			label: "consume",
			resource_effect: "decrement",
			onhand_effect: "decrement",
			input_output: "input",
			pairs_with: "notApplicable",
		},
		"cite" => %__MODULE__{
			id: "cite",
			label: "cite",
			resource_effect: "noEffect",
			onhand_effect: "noEffect",
			input_output: "input",
			pairs_with: "notApplicable",
		},
		"deliverService" => %__MODULE__{
			id: "deliverService",
			label: "deliver-service",
			resource_effect: "noEffect",
			onhand_effect: "noEffect",
			input_output: "inputOutput",
			pairs_with: "notApplicable",
		},
		"work" => %__MODULE__{
			id: "work",
			label: "work",
			resource_effect: "noEffect",
			onhand_effect: "noEffect",
			input_output: "input",
			pairs_with: "notApplicable",
		},
		"pickup" => %__MODULE__{
			id: "pickup",
			label: "pickup",
			resource_effect: "noEffect",
			onhand_effect: "noEffect",
			input_output: "input",
			pairs_with: "dropoff",
		},
		"dropoff" => %__MODULE__{
			id: "dropoff",
			label: "dropoff",
			resource_effect: "noEffect",
			onhand_effect: "noEffect",
			input_output: "output",
			pairs_with: "pickup",
		},
		"accept" => %__MODULE__{
			id: "accept",
			label: "accept",
			resource_effect: "noEffect",
			onhand_effect: "input",
			input_output: "notApplicable",
			pairs_with: "modify",
		},
		"modify" => %__MODULE__{
			id: "modify",
			label: "modify",
			resource_effect: "noEffect",
			onhand_effect: "noEffect",
			input_output: "output",
			pairs_with: "modify",
		},
		"combine" => %__MODULE__{
			id: "combine",
			label: "combine",
			resource_effect: "noEffect",
			onhand_effect: "decrement",
			input_output: "input",
			pairs_with: "modify",
		},
		"separate" => %__MODULE__{
			id: "separate",
			label: "separate",
			resource_effect: "noEffect",
			onhand_effect: "increment",
			input_output: "output",
			pairs_with: "accept",
		},
		"transferAllRights" => %__MODULE__{
			id: "transferAllRights",
			label: "transfer-all-rights",
			resource_effect: "decrementIncrement",
			onhand_effect: "noEffect",
			input_output: "notApplicable",
			pairs_with: "notApplicable",
		},
		"transferCustody" => %__MODULE__{
			id: "transferCustody",
			label: "transfer-custody",
			resource_effect: "noEffect",
			onhand_effect: "decrementIncrement",
			input_output: "notApplicable",
			pairs_with: "notApplicable",
		},
		"transfer" => %__MODULE__{
			id: "transfer",
			label: "transfer",
			resource_effect: "decrementIncrement",
			onhand_effect: "decrementIncrement",
			input_output: "notApplicable",
			pairs_with: "notApplicable",
		},
		"move" => %__MODULE__{
			id: "move",
			label: "move",
			resource_effect: "decrementIncrement",
			onhand_effect: "decrementIncrement",
			input_output: "notApplicable",
			pairs_with: "notApplicable",
		},
		"raise" => %__MODULE__{
			id: "raise",
			label: "raise",
			resource_effect: "increment",
			onhand_effect: "increment",
			input_output: "notApplicable",
			pairs_with: "notApplicable",
		},
		"lower" => %__MODULE__{
			id: "lower",
			label: "lower",
			resource_effect: "decrement",
			onhand_effect: "decrement",
			input_output: "notApplicable",
			pairs_with: "notApplicable",
		},
	}
end
end
