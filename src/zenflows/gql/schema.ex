defmodule Zenflows.GQL.Schema do
@moduledoc "Absinthe schema."

use Absinthe.Schema

alias Zenflows.VF
alias Zenflows.GQL.MW

import_types Absinthe.Type.Custom
import_types Zenflows.GQL.Type
import_types Zenflows.SWPass.Type

import_types VF.TimeUnit.Type
import_types VF.Action.Type
import_types VF.Duration.Type
import_types VF.Unit.Type
import_types VF.Measure.Type
import_types VF.SpatialThing.Type
import_types VF.ProcessSpecification.Type
import_types VF.ResourceSpecification.Type
import_types VF.RecipeResource.Type
import_types VF.RecipeProcess.Type
import_types VF.RecipeExchange.Type
import_types VF.RecipeFlow.Type
import_types VF.Person.Type
import_types VF.Organization.Type
#import_types VF.AccountingScope.Type
import_types VF.Agent.Type
import_types VF.RoleBehavior.Type
import_types VF.AgentRelationshipRole.Type
import_types VF.AgentRelationship.Type
import_types VF.Agreement.Type
import_types VF.ScenarioDefinition.Type
import_types VF.Scenario.Type
import_types VF.Plan.Type
import_types VF.Process.Type
import_types VF.ProductBatch.Type
import_types VF.EconomicResource.Type
import_types VF.EconomicEvent.Type
#import_types VF.Appreciation.Type
#import_types VF.Intent.Type
#import_types VF.Commitment.Type
#import_types VF.Fulfillment.Type
#import_types VF.EventOrCommitment.Type
#import_types VF.Satisfaction.Type
#import_types VF.Claim.Type
#import_types VF.Settlement.Type
#import_types VF.Proposal.Type
#import_types VF.ProposedIntent.Type
#import_types VF.ProposedTo.Type

query do
	import_fields :query_sw_pass

	import_fields :query_unit
	import_fields :query_spatial_thing
	import_fields :query_process_specification
	import_fields :query_resource_specification
	import_fields :query_recipe_resource
	import_fields :query_recipe_process
	import_fields :query_recipe_exchange
	import_fields :query_recipe_flow
	import_fields :query_person
	import_fields :query_organization
	#import_fields :query_accounting_scope
	import_fields :query_agent
	import_fields :query_role_behavior
	import_fields :query_agent_relationship_role
	import_fields :query_agent_relationship
	import_fields :query_agreement
	import_fields :query_scenario_definition
	import_fields :query_scenario
	import_fields :query_plan
	import_fields :query_process
	import_fields :query_product_batch
	import_fields :query_economic_resource
	import_fields :query_economic_event
	#import_fields :query_appreciation
	#import_fields :query_intent
	#import_fields :query_commitment
	#import_fields :query_fulfillment
	#import_fields :query_event_or_commitment
	#import_fields :query_satisfaction
	#import_fields :query_claim
	#import_fields :query_settlement
	#import_fields :query_proposal
	#import_fields :query_proposed_intent
	#import_fields :query_proposed_to
end

mutation do
	import_fields :mutation_sw_pass

	import_fields :mutation_unit
	import_fields :mutation_spatial_thing
	import_fields :mutation_process_specification
	import_fields :mutation_resource_specification
	import_fields :mutation_recipe_resource
	import_fields :mutation_recipe_process
	import_fields :mutation_recipe_exchange
	import_fields :mutation_recipe_flow
	import_fields :mutation_person
	import_fields :mutation_organization
	#import_fields :mutation_accounting_scope
	#import_fields :mutation_agent
	import_fields :mutation_role_behavior
	import_fields :mutation_agent_relationship_role
	import_fields :mutation_agent_relationship
	import_fields :mutation_agreement
	import_fields :mutation_scenario_definition
	import_fields :mutation_scenario
	import_fields :mutation_plan
	import_fields :mutation_process
	import_fields :mutation_product_batch
	import_fields :mutation_economic_resource
	import_fields :mutation_economic_event
	#import_fields :mutation_appreciation
	#import_fields :mutation_intent
	#import_fields :mutation_commitment
	#import_fields :mutation_fulfillment
	#import_fields :mutation_event_or_commitment
	#import_fields :mutation_satisfaction
	#import_fields :mutation_claim
	#import_fields :mutation_settlement
	#import_fields :mutation_proposal
	#import_fields :mutation_proposed_intent
	#import_fields :mutation_proposed_to
end

@impl true
def middleware(mw, %{identifier: ident}, _)
		when ident in ~w[create_person delete_person import_repos]a do
	mw ++ [MW.Errors, MW.Admin]
end

def middleware(mw, _, _) do
	mw ++ [MW.Errors, MW.Sign]
end

@impl true
#def hydrate(%Absinthe.Blueprint.Schema.ScalarTypeDefinition{identifier: :id}, %{identifier: :action}) do
#	[
#		parse: &Zenflows.VF.Action.ID.cast/1,
#		description:
#			"'produce', 'use', 'consum', etc.",
#	]
#end
def hydrate(%Absinthe.Blueprint.Schema.ScalarTypeDefinition{identifier: :id}, _) do
	[
		# The main intention here is to override parsing, thus
		# adding validation to the default ID type.
		parse: &Zenflows.GQL.Type.id_parse/1,
		description:
			"A URL-safe Base64-encoded, 22 characters-long String identifier.",
	]
end

def hydrate(_, _) do
	[]
end
end
