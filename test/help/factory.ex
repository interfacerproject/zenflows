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

defmodule ZenflowsTest.Help.Factory do
@moduledoc """
Defines shortcuts for DB testing.
"""

alias Zenflows.DB.Repo
alias Zenflows.VF

defdelegate id(), to: Zenflows.DB.ID, as: :gen

@doc "Returns `DateTime.utc_now/0`."
@spec now() :: DateTime.t()
def now() do
	DateTime.utc_now()
end

@doc "Like `now/0`, but piped to `DateTime.to_iso8601/1`."
@spec iso_now() :: String.t()
def iso_now() do
	now() |> DateTime.to_iso8601()
end

@doc """
Returns the same string with a unique positive integer attached at
the end.
"""
@spec str(String.t()) :: String.t()
def str(s) do
	"#{s}#{System.unique_integer([:positive])}"
end

@doc """
Returns a list of string composed of one or ten items.  Each item is
generated by piping `str` to `uniq/1`
"""
@spec str_list(String.t(), non_neg_integer(), non_neg_integer()) :: [String.t()]
def str_list(s, min \\ 1, max \\ 10) do
	max = Enum.random(1..max)
	Enum.map(min..max, fn _ -> str(s) end)
end

@doc """
Returns a random integer between 0 (inclusive) and `max` (exclusive).
"""
@spec int() :: integer()
def int(max \\ 100) do
	ceil(float(max))
end

@doc """
Returns a random float between 0 (inclusive) and 1 (exclusive)
multiplied by `mul`, which is 100 by default.
"""
@spec float() :: float()
def float(mul \\ 100) do
	:rand.uniform() * mul
end

@doc """
Returns a string that represents a `t:Decimal.t()` between 0
(inclusive) and 1 (exclusive) multiplied by `mul`, which is 100 by
default.
"""
@spec decimal() :: String.t()
def decimal(mul \\ 100) do
	to_string(decimald(mul))
end

@doc """
Returns a `t:Decimal.t()` between 0 (inclusive) and 1 (exclusive)
multiplied by `mul`, which is 100 by default.
"""
@spec decimald() :: Decimal.t()
def decimald(mul \\ 100) do
	Decimal.from_float(float(mul))
end

@doc "Returns a random boolean."
@spec bool() :: boolean()
def bool() do
	:rand.uniform() < 0.5
end

@doc "Returns a unique URI string."
@spec uri() :: String.t()
def uri() do
	str("schema://user@host:port/path")
end

@doc "Returns a file list."
@spec file_list(non_neg_integer(), non_neg_integer()) :: [File.t()]
def file_list(min \\ 1, max \\ 10) do
	max = Enum.random(1..max)
	Enum.map(min..max, fn _ ->
		bin = str("some binary")
		hash = :crypto.hash(:sha512, bin) |> Base.url_encode64(padding: false)
		%Zenflows.File{
			name: str("some name"),
			description: str("some description"),
			mime_type: str("some mime type"),
			extension: str("some extension"),
			signature: str("some signature"),
			bin: bin,
			hash: hash,
			size: byte_size(bin),
		}
	end)
end

@doc "Inserts a schema into the database with field overrides."
@spec insert!(atom(), %{required(atom()) => term()}) :: struct()
def insert!(_, _ \\ %{})
def insert!(:economic_event, _), do: insert_economic_event!()
def insert!(:economic_resource, _), do: insert_economic_resource!()
def insert!(name, params) do
	name |> build!(params) |> Repo.insert!()
end

@doc "Builds a schema with field overrides."
@spec build!(atom(), %{required(atom()) => term()}) :: struct()
def build!(name, params \\ %{}) do
	name |> build() |> struct!(params)
end

@doc """
Like `build!/2`, but returns just a map.
Useful for things like IDuration in the GraphQL spec.
"""
@spec build_map!(atom()) :: map()
def build_map!(name) do
	build!(name)
	|> Map.delete(:__struct__)
	|> Map.delete(:__meta__)
end

def build(:time_unit) do
	Enum.random(VF.TimeUnit.values())
end

def build(:iduration) do
	%{
		unit_type: build(:time_unit),
		numeric_duration: decimald(),
	}
end

def build(:unit) do
	%VF.Unit{
		label: str("some label"),
		symbol: str("some symbol"),
	}
end

def build(:imeasure) do
	%VF.Measure{
		has_unit: build(:unit),
		has_numerical_value: decimald(),
	}
end

def build(:spatial_thing) do
	%VF.SpatialThing{
		name: str("some name"),
		mappable_address: str("some mappable_address"),
		lat: decimald(),
		long: decimald(),
		alt: decimald(),
		note: str("some note"),
	}
end

def build(:action_id) do
	Enum.random(VF.Action.ID.values())
end

def build(:process_specification) do
	%VF.ProcessSpecification{
		name: str("some name"),
		note: str("some note"),
	}
end

def build(:resource_specification) do
	%VF.ResourceSpecification{
		name: str("some name"),
		resource_classified_as: str_list("some uri"),
		note: str("some note"),
		images: file_list(),
		default_unit_of_effort: build(:unit),
		default_unit_of_resource: build(:unit),
	}
end

def build(:recipe_resource) do
	%VF.RecipeResource{
		name: str("some name"),
		unit_of_resource: build(:unit),
		unit_of_effort: build(:unit),
		resource_classified_as: str_list("some uri"),
		resource_conforms_to: build(:resource_specification),
		substitutable: bool(),
		note: str("some note"),
		images: file_list(),
	}
end

def build(:recipe_process) do
	dur = build(:iduration)
	%VF.RecipeProcess{
		name: str("some name"),
		note: str("some note"),
		process_classified_as: str_list("some uri"),
		process_conforms_to: build(:process_specification),
		has_duration_unit_type: dur.unit_type,
		has_duration_numeric_duration: dur.numeric_duration,
	}
end

def build(:recipe_exchange) do
	%VF.RecipeExchange{
		name: str("some name"),
		note: str("some note"),
	}
end

def build(:recipe_flow) do
	resqty = build(:imeasure)
	effqty = build(:imeasure)
	%VF.RecipeFlow{
		action_id: build(:action_id),
		recipe_input_of: build(:recipe_process),
		recipe_output_of: build(:recipe_process),
		recipe_flow_resource: build(:recipe_resource),
		resource_quantity_has_unit: resqty.has_unit,
		resource_quantity_has_numerical_value: resqty.has_numerical_value,
		effort_quantity_has_unit: effqty.has_unit,
		effort_quantity_has_numerical_value: effqty.has_numerical_value,
		recipe_clause_of: build(:recipe_exchange),
		note: str("some note"),
	}
end

def build(:person) do
	%VF.Person{
		type: :per,
		name: str("some name"),
		images: file_list(),
		note: str("some note"),
		primary_location: build(:spatial_thing),
		user: str("some user"),
		email: "#{str("user")}@example.com",
		# Normally, these are encoded by zenroom (with whatever
		# encodings it chooses to use), but for testing, this'll
		# work alright.
		ecdh_public_key: Base.encode64("some ecdh_public_key"),
		eddsa_public_key: Base.encode64("some eddsa_public_key"),
		ethereum_address: Base.encode64("some ethereum_address"),
		reflow_public_key: Base.encode64("some reflow_public_key"),
		schnorr_public_key: Base.encode64("some schnorr_public_key"),
	}
end

def build(:organization) do
	%VF.Organization{
		type: :org,
		name: str("some name"),
		images: file_list(),
		classified_as: str_list("some uri"),
		note: str("some note"),
		primary_location: build(:spatial_thing),
	}
end

def build(:agent) do
	type = if(bool(), do: :person, else: :person)
	struct(VF.Agent, build_map!(type))
end

def build(:role_behavior) do
	%VF.RoleBehavior{
		name: str("some name"),
		note: str("some note"),
	}
end

def build(:agent_relationship_role) do
	%VF.AgentRelationshipRole{
		role_behavior: build(:role_behavior),
		role_label: str("some role label"),
		inverse_role_label: str("some role label"),
		note: str("some note"),
	}
end

def build(:agent_relationship) do
	%VF.AgentRelationship{
		subject: build(:agent),
		object: build(:agent),
		relationship: build(:agent_relationship_role),
		# in_scope_of:
		note: str("some note"),
	}
end

def build(:agreement) do
	%VF.Agreement{
		name: str("some name"),
		note: str("some note"),
	}
end

def build(:scenario_definition) do
	dur = build(:iduration)
	%VF.ScenarioDefinition{
		name: str("some name"),
		note: str("some note"),
		has_duration_unit_type: dur.unit_type,
		has_duration_numeric_duration: dur.numeric_duration,
	}
end

def build(:scenario) do
	recurse? = bool()

	%VF.Scenario{
		name: str("some name"),
		note: str("some note"),
		has_beginning: now(),
		has_end: now(),
		defined_as: build(:scenario_definition),
		refinement_of: if(recurse?, do: build(:scenario)),
	}
end

def build(:plan) do
	%VF.Plan{
		name: str("some name"),
		due: now(),
		note: str("some note"),
		refinement_of: build(:scenario),
	}
end

def build(:process) do
	%VF.Process{
		name: str("some name"),
		note: str("some note"),
		has_beginning: now(),
		has_end: now(),
		finished: bool(),
		classified_as: str_list("some uri"),
		based_on: build(:process_specification),
		# in_scope_of:
		planned_within: build(:plan),
		nested_in: build(:scenario),
	}
end

def build(:product_batch) do
	%VF.ProductBatch{
		batch_number: str("some batch number"),
		expiry_date: now(),
		production_date: now(),
	}
end

def build(:appreciation) do
	%VF.Appreciation{
		appreciation_of: build(:economic_event),
		appreciation_with: build(:economic_event),
		note: str("some note"),
	}
end

def build(:intent) do
	agent_mutex? = bool()
	resqty = build(:imeasure)
	effqty = build(:imeasure)
	availqty = build(:imeasure)

	%VF.Intent{
		name: str("some name"),
		action_id: build(:action_id),
		provider: if(agent_mutex?, do: build(:agent)),
		receiver: unless(agent_mutex?, do: build(:agent)),
		input_of: build(:process),
		output_of: build(:process),
		resource_classified_as: str_list("some uri"),
		resource_conforms_to: build(:resource_specification),
		resource_inventoried_as_id: insert_economic_resource!().id,
		resource_quantity_has_unit: resqty.has_unit,
		resource_quantity_has_numerical_value: resqty.has_numerical_value,
		effort_quantity_has_unit: effqty.has_unit,
		effort_quantity_has_numerical_value: effqty.has_numerical_value,
		available_quantity_has_unit: availqty.has_unit,
		available_quantity_has_numerical_value: availqty.has_numerical_value,
		at_location: build(:spatial_thing),
		has_beginning: now(),
		has_end: now(),
		has_point_in_time: now(),
		due: now(),
		finished: bool(),
		images: file_list(),
		note: str("some note"),
		# in_scope_of:
		agreed_in: str("some uri"),
	}
end

def build(:commitment) do
	datetime_mutex? = bool()
	resource_mutex? = bool()
	resqty = build(:imeasure)
	effqty = build(:imeasure)

	%VF.Commitment{
		action_id: build(:action_id),
		provider: build(:agent),
		receiver: build(:agent),
		input_of: build(:process),
		output_of: build(:process),
		resource_classified_as: str_list("some uri"),
		resource_conforms_to: if(resource_mutex?, do: build(:resource_specification)),
		resource_inventoried_as_id: unless(resource_mutex?, do: insert_economic_resource!().id),
		resource_quantity_has_unit: resqty.has_unit,
		resource_quantity_has_numerical_value: resqty.has_numerical_value,
		effort_quantity_has_unit: effqty.has_unit,
		effort_quantity_has_numerical_value: effqty.has_numerical_value,
		has_beginning: if(datetime_mutex?, do: now()),
		has_end: if(datetime_mutex?, do: now()),
		has_point_in_time: unless(datetime_mutex?, do: now()),
		due: now(),
		finished: bool(),
		note: str("some note"),
		# in_scope_of:
		agreed_in: str("some uri"),
		independent_demand_of: build(:plan),
		at_location: build(:spatial_thing),
		clause_of: build(:agreement),
	}
end

def build(:fulfillment) do
	resqty = build(:imeasure)
	effqty = build(:imeasure)

	%VF.Fulfillment{
		note: str("some note"),
		fulfilled_by: build(:economic_event),
		fulfills: build(:commitment),
		resource_quantity_has_unit: resqty.has_unit,
		resource_quantity_has_numerical_value: resqty.has_numerical_value,
		effort_quantity_has_unit: effqty.has_unit,
		effort_quantity_has_numerical_value: effqty.has_numerical_value,
	}
end

def build(:event_or_commitment) do
	mutex? = bool()

	%VF.EventOrCommitment{
		event: if(mutex?, do: build(:economic_event)),
		commitment: unless(mutex?, do: build(:commitment)),
	}
end

def build(:satisfaction) do
	resqty = build(:imeasure)
	effqty = build(:imeasure)

	%VF.Satisfaction{
		satisfied_by: build(:event_or_commitment),
		satisfies: build(:intent),
		resource_quantity_has_unit: resqty.has_unit,
		resource_quantity_has_numerical_value: resqty.has_numerical_value,
		effort_quantity_has_unit: effqty.has_unit,
		effort_quantity_has_numerical_value: effqty.has_numerical_value,
		note: str("some note"),
	}
end

def build(:claim) do
	resqty = build(:imeasure)
	effqty = build(:imeasure)

	%VF.Claim{
		action_id: build(:action_id),
		provider: build(:agent),
		receiver: build(:agent),
		resource_classified_as: str_list("some uri"),
		resource_conforms_to: build(:resource_specification),
		resource_quantity_has_unit: resqty.has_unit,
		resource_quantity_has_numerical_value: resqty.has_numerical_value,
		effort_quantity_has_unit: effqty.has_unit,
		effort_quantity_has_numerical_value: effqty.has_numerical_value,
		triggered_by: if(bool(), do: build(:economic_event), else: nil),
		due: now(),
		finished: bool(),
		agreed_in: str("some uri"),
		note: str("some note"),
		# in_scope_of:
	}
end

def build(:settlement) do
	resqty = build(:imeasure)
	effqty = build(:imeasure)

	%VF.Settlement{
		settled_by: build(:economic_event),
		settles: build(:claim),
		resource_quantity_has_unit: resqty.has_unit,
		resource_quantity_has_numerical_value: resqty.has_numerical_value,
		effort_quantity_has_unit: effqty.has_unit,
		effort_quantity_has_numerical_value: effqty.has_numerical_value,
		note: str("some note"),
	}
end

def build(:proposal) do
	%VF.Proposal{
		name: str("some name"),
		has_beginning: now(),
		has_end: now(),
		unit_based: bool(),
		note: str("some note"),
		eligible_location: build(:spatial_thing),
	}
end

def build(:proposed_intent) do
	%VF.ProposedIntent{
		reciprocal: bool(),
		publishes: build(:intent),
		published_in: build(:proposal),
	}
end

def build(:proposed_to) do
	%VF.ProposedTo{
		proposed_to: build(:agent),
		proposed: build(:proposal),
	}
end

def insert_economic_event!() do
	agent = insert!(:agent)
	Zenflows.VF.EconomicEvent.Domain.create!(%{
		action_id: "raise",
		provider_id: agent.id,
		receiver_id: agent.id,
		resource_classified_as: str_list("some uri"),
		resource_conforms_to_id: insert!(:resource_specification).id,
		resource_quantity: %{
			has_numerical_value: decimald(),
			has_unit_id: insert!(:unit).id,
		},
		has_point_in_time: now(),
	}, %{name: str("some name")})
end

def insert_economic_resource!() do
	%{resource_inventoried_as_id: id} = insert_economic_event!()
	Zenflows.VF.EconomicResource.Domain.one!(id)
end
end
