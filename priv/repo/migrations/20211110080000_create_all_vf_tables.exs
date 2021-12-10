defmodule Zenflows.Ecto.Repo.Migrations.Create_vf_tables do
# New tables can be added on top of these as anoter migration files.
# The point of this migration is to just prevent circular references.

use Ecto.Migration

def change() do
	execute "CREATE EXTENSION citext", "DROP EXTENSION citext"

	create table("vf_duration")
	create table("vf_unit")
	create table("vf_measure")
	create table("vf_spatial_thing")
	create table("vf_process_specification")
	create table("vf_resource_specification")
	create table("vf_recipe_resource")
	create table("vf_recipe_process")
	create table("vf_recipe_exchange")
	create table("vf_recipe_flow")
	#create table("vf_accounting_scope")
	create table("vf_agent")
	create table("vf_role_behavior")
	create table("vf_agent_relationship_role")
	create table("vf_agent_relationship")
	create table("vf_agreement")
	create table("vf_scenario_definition")
	create table("vf_scenario")
	create table("vf_plan")
	create table("vf_process")
	create table("vf_product_batch")
	create table("vf_economic_resource")
	create table("vf_economic_event")
	create table("vf_appreciation")
	create table("vf_intent")
	create table("vf_commitment")
	create table("vf_fulfillment")
	create table("vf_event_or_commitment")
	create table("vf_satisfaction")
	create table("vf_claim")
	create table("vf_settlement")
	create table("vf_proposal")
	create table("vf_proposed_intent")
	create table("vf_proposed_to")
end
end
