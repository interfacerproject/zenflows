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

defmodule Zenflows.Project.Domain do
@moduledoc "Domain logic of Project flows"

alias Ecto.Changeset
alias Zenflows.InstVars
alias Zenflows.DB.{ID, Repo, Schema}
alias Zenflows.VF.{
	EconomicEvent,
	EconomicResource,
	Intent,
	Person,
	Process,
	Proposal,
	ProposedIntent,
	SpatialThing,
}
alias Zenflows.Wallet

def idea_points(), do: %{
	on_fork: 100,
	on_create: 100,
	on_contributions: 100,
	on_accept: 100,
	on_cite: 100,
}
def strengths_points(), do: %{
	on_fork: 100,
	on_create: 100,
	on_contributions: 100,
	on_accept: 100,
	on_cite: 100,
}

# `maybe_create_location` creates a SpatialThing if `params.location` is
# supplied and valid; else, it returns `nil` for the SpatialThing.
@spec maybe_create_location(Schema.params())
	:: {:ok, {nil | SpatialThing.t(), boolean()}} | {:error, Changeset.t()}
defp maybe_create_location(params) do
	remote? = params.location_remote || params.project_type == :design
	if params.location != nil do
		%{
			name: params.location_name || params.location.address,
			mappable_address: params.location.address,
			lat: params.location.lat,
			lng: params.location.lng,
		}
		|> SpatialThing.Domain.create()
		|> case do
			{:ok, st} -> {:ok, {st, remote?}}
			{:error, reason} -> {:error, reason}
		end
	else
		{:ok, {nil, remote?}}
	end
end

# `is_resource_design?` receives an id parameter, and whenever it
# is not nil, it checks if the resource referenced by that id exists
# or not; in the case that it exists, it returns true.
@spec is_resource_design?(nil | ID.t()) :: {:ok, boolean()} | {:error, String.t()}
defp is_resource_design?(nil), do: {:ok, false}
defp is_resource_design?(id) do
	case EconomicResource.Domain.one(id) do
		{:ok, _} -> {:ok, true}
		{:error, reason} -> {:error, reason}
	end
end

@spec create(Schema.params()) :: {:ok, EconomicEvent.t()} | {:error, Changeset.t()}
def create(params) do
	inst_vars = InstVars.Domain.get()
	project_types = %{
		design: inst_vars.specs.spec_project_design.id,
		service: inst_vars.specs.spec_project_service.id,
		product: inst_vars.specs.spec_project_product.id
	}

	Repo.multi(fn ->
		with {:ok, owner} <- Person.Domain.one(params.owner_id),
				{:ok, process} <-
					%{name: "creation of #{params.title} by #{owner.name}"}
					|> Process.Domain.create(),
				{:ok, {location, remote?}} <- maybe_create_location(params),
				# TODO: `resource_metadata` should check that the `linked_design_id` exists somehow.
				{:ok, design?} <- is_resource_design?(params[:linked_design_id]),
				{:ok, evt} <- EconomicEvent.Domain.create(
					%{
						action_id: "produce",
						provider_id: owner.id,
						receiver_id: owner.id,
						output_of_id: process.id,
						has_point_in_time: DateTime.utc_now(),
						resource_classified_as: params.tags,
						resource_conforms_to_id: project_types[String.to_existing_atom(params.project_type)],
						resource_quantity: %{has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id},
						to_location_id: if(location != nil, do: location.id, else: nil),
						resource_metadata: %{
							contributors: params.contributors,
							licenses: params.licenses,
							relations: params.relations,
							declarations: params.declarations,
							remote: remote?,
							design: design?,
						},
					},
					%{
						name: params.title,
						note: params.description,
						images: params.images,
						repo: params.link,
						license: get_in(params.licenses, [Access.at(0), :license_id]),
					}
				),
				# economic system: points assignments
				{:ok} = Wallet.add_points(idea_points().on_create, params.owner_id, :idea),
				{:ok} = Wallet.add_points(strengths_points().on_create, params.owner_id, :strengths) do
			{:ok, evt}
		end
	end)
end

@spec add_contributor(Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, Changeset.t()}
def add_contributor(params) do
	inst_vars = InstVars.Domain.get()

	Repo.multi(fn ->
		with {:ok, evt} <- EconomicEvent.Domain.create(%{
					action_id: "work",
					provider_id: params.contributor_id,
					receiver_id: params.contributor_id,
					input_of_id: params.process_id,
					has_point_in_time: DateTime.utc_now(),
					resource_conforms_to_id: inst_vars.specs.spec_project_design.id,
					effort_quantity: %{has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id},
				}),
				# economic system: points assignments
				{:ok} = Wallet.add_points(idea_points().on_contributions, params.owner_id, :idea),
				{:ok} = Wallet.add_points(strengths_points().on_contributions, params.contributor_id, :strengths) do

			{:ok, evt}
		end
	end)
end

@spec fork(Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, Changeset.t()}
def fork(params) do
	inst_vars = InstVars.Domain.get()

	Repo.multi(fn ->
		with {:ok, owner} <- Person.Domain.one(params.owner_id),
				{:ok, resource} <- EconomicResource.Domain.one(params.resource_id),
				{:ok, process} <-
					%{name: "fork of #{resource.name} by #{owner.name}"}
					|> Process.Domain.create(),
				{:ok, _} <- EconomicEvent.Domain.create(
					%{
						action_id: "cite",
						input_of_id: process.id,
						provider_id: owner.id,
						receiver_id: owner.id,
						has_point_in_time: DateTime.utc_now(),
						resource_inventoried_as_id: resource.id,
						resource_quantity: %{has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id},
					}
				),
				{:ok, forked_evt} <- EconomicEvent.Domain.create(
					%{
						action_id: "produce",
						provider_id: owner.id,
						receiver_id: owner.id,
						output_of_id: process.id,
						has_point_in_time: DateTime.utc_now(),
						resource_classified_as: resource.classified_as,
						resource_conforms_to_id: resource.conforms_to_id,
						resource_quantity: %{has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id},
						to_location_id: resource.current_location_id,
						resource_metadata: if(resource.metadata[:relations] != nil,
							do: put_in(resource.metadata, [:relations],
									resource.metadata.relations ++ [resource.id]),
							else: nil)
					},
					%{
						name: "#{resource.name} resource forked by #{owner.name}",
						note: params.description,
						repo: params.contribution_repository,
					}
				),
				{:ok, process_contribution} <-
					%{name: "contribution of ${resource.name} by ${owner.name"}
					|> Process.Domain.create(),
				{:ok, proposal} <- Proposal.Domain.create(
					%{name: process.name, note: params.description}
				),

				# Propose contribution
				{:ok, cite_resource_forked} <- Intent.Domain.create(%{
						action_id: "cite",
						input_of_id: process_contribution.id,
						provider_id: resource.primary_accountable_id,
						has_point_in_time: DateTime.utc_now(),
						resource_inventoried_as_id: forked_evt.resource_inventoried_as_id,
						resource_quantity: %{has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id},
					}),
				{:ok, accept_resource_origin} <- Intent.Domain.create(%{
						action_id: "accept",
						input_of_id: process_contribution.id,
						receiver_id: owner.id,
						has_point_in_time: DateTime.utc_now(),
						resource_inventoried_as_id: resource.id,
						resource_quantity: %{has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id},
					}),
				{:ok, modify_resource_origin} <- Intent.Domain.create(%{
						action_id: "modify",
						output_of_id: process_contribution.id,
						receiver_id: owner.id,
						has_point_in_time: DateTime.utc_now(),
						resource_inventoried_as_id: resource.id,
						resource_quantity: %{has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id},
					}),
				# Link proposal and intent
				{:ok, _} <- ProposedIntent.Domain.create(%{
						published_in_id: proposal.id,
						publishes_id: cite_resource_forked.id,
					}),
				{:ok, _} <- ProposedIntent.Domain.create(%{
						published_in_id: proposal.id,
						publishes_id: accept_resource_origin.id,
					}),
				{:ok, _} <- ProposedIntent.Domain.create(%{
						published_in_id: proposal.id,
						publishes_id: modify_resource_origin.id,
					}),
				# economic system: points assignments
				{:ok} = Wallet.add_points(idea_points().on_fork, resource.primary_accountable_id, :idea),
				{:ok} = Wallet.add_points(strengths_points().on_fork, params.owner_id, :strengths) do

			{:ok, %{proposal: proposal, fork_event: forked_evt}}
		end
	end)
end

@spec cite(Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, Changeset.t()}
def cite(params) do
	inst_vars = InstVars.Domain.get()

	Repo.multi(fn ->
		# TODO: we should check that the `process_id` exist somehow.
		with {:ok, resource} = EconomicResource.Domain.one(params.resource_id),
				{:ok, evt} <- EconomicEvent.Domain.create(%{
					action_id: "cite",
					input_of_id: params.process_id,
					provider_id: params.owner_id,
					receiver_id: params.owner_id,
					has_point_in_time: DateTime.utc_now(),
					resource_inventoried_as_id: params.resource_id,
					resource_quantity: %{has_numerical_value: 1, has_unit_id: inst_vars.units.unit_one.id},
				}),
				# economic system: points assignments
				{:ok} = Wallet.add_points(idea_points().on_cite, params.owner_id, :idea),
				{:ok} = Wallet.add_points(strengths_points().on_cite, resource.primary_accountable_id, :strengths) do

			{:ok, evt}
		end
	end)
end

@spec approve(Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, Changeset.t()}
def approve(params) do
	inst_vars = InstVars.Domain.get()

	Repo.multi(fn ->
		with {:ok, proposal} <- Proposal.Domain.one(params.proposal_id),
				proposal <- Repo.preload(proposal, :primary_intents) do

			{:ok, proposal}
		end
	end)
end
end
