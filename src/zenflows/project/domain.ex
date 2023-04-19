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

@spec idea_points() :: %{
	on_fork: Decimal.t(),
	on_create: Decimal.t(),
	on_contributions: Decimal.t(),
	on_accept: Decimal.t(),
	on_cite: Decimal.t(),
}
defp idea_points() do
	%{
		on_fork: Decimal.new("100"),
		on_create: Decimal.new("100"),
		on_contributions: Decimal.new("100"),
		on_accept: Decimal.new("100"),
		on_cite: Decimal.new("100"),
	}
end

@spec strength_points() :: %{
	on_fork: Decimal.t(),
	on_create: Decimal.t(),
	on_contributions: Decimal.t(),
	on_accept: Decimal.t(),
	on_cite: Decimal.t(),
}
defp strength_points() do
	%{
		on_fork: Decimal.new("100"),
		on_create: Decimal.new("100"),
		on_contributions: Decimal.new("100"),
		on_accept: Decimal.new("100"),
		on_cite: Decimal.new("100"),
	}
end

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

@spec fetch_spec_id(:design | :service | :product) :: ID.t()
defp fetch_spec_id(:design),
	do: InstVars.Domain.get().specs.spec_project_design.id
defp fetch_spec_id(:service),
	do: InstVars.Domain.get().specs.spec_project_service.id
defp fetch_spec_id(:product),
	do: InstVars.Domain.get().specs.spec_project_product.id

@spec build_quantity() :: %{has_numerical_value: 1, has_unit_id: ID.t()}
defp build_quantity() do
	%{
		has_numerical_value: 1,
		has_unit_id: InstVars.Domain.get().units.unit_one.id,
	}
end

@spec create(Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, String.t() | Changeset.t()}
def create(params) do
	Repo.multi(fn ->
		with {:ok, owner} <- Person.Domain.one(params.owner_id),
				{:ok, process} <-
					Process.Domain.create(%{name: "creation of #{params.title} by #{owner.name}"}),
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
						resource_conforms_to_id: fetch_spec_id(params.project_type),
						resource_quantity: build_quantity(),
						to_location_id: if(location != nil, do: location.id),
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
				:ok <- Wallet.add_idea_points(params.owner_id, idea_points().on_create),
				:ok <- Wallet.add_strength_points(params.owner_id, strength_points().on_create) do
			{:ok, evt}
		else
			:error -> {:error, "couldn't add points"}
			{:error, reason} -> {:error, reason}
		end
	end)
end

@spec add_contributor(Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, String.t() | Changeset.t()}
def add_contributor(params) do
	Repo.multi(fn ->
		with {:ok, evt} <- EconomicEvent.Domain.create(%{
					action_id: "work",
					provider_id: params.contributor_id,
					receiver_id: params.contributor_id,
					input_of_id: params.process_id,
					has_point_in_time: DateTime.utc_now(),
					resource_conforms_to_id: fetch_spec_id(:design),
					effort_quantity: build_quantity(),
				}),
				# economic system: points assignments
				:ok <- Wallet.add_idea_points(params.owner_id, idea_points().on_contributions),
				:ok <- Wallet.add_strength_points(params.contributor_id, strength_points().on_contributions) do
			{:ok, evt}
		else
			:error -> {:error, "couldn't add points"}
			{:error, reason} -> {:error, reason}
		end
	end)
end

@spec fork(Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, String.t() | Changeset.t()}
def fork(params) do
	Repo.multi(fn ->
		with {:ok, owner} <- Person.Domain.one(params.owner_id),
				{:ok, resource} <- EconomicResource.Domain.one(params.resource_id),
				{:ok, process} <-
					Process.Domain.create(%{name: "fork of #{resource.name} by #{owner.name}"}),
				{:ok, _} <- EconomicEvent.Domain.create(%{
						action_id: "cite",
						input_of_id: process.id,
						provider_id: owner.id,
						receiver_id: owner.id,
						has_point_in_time: DateTime.utc_now(),
						resource_inventoried_as_id: resource.id,
						resource_quantity: build_quantity(),
				}),
				{:ok, forking_evt} <- EconomicEvent.Domain.create(
					%{
						action_id: "produce",
						provider_id: owner.id,
						receiver_id: owner.id,
						output_of_id: process.id,
						has_point_in_time: DateTime.utc_now(),
						resource_classified_as: resource.classified_as,
						resource_conforms_to_id: resource.conforms_to_id,
						resource_quantity: build_quantity(),
						to_location_id: resource.current_location_id,
						resource_metadata: if(resource.metadata[:relations] != nil,
							do: put_in(resource.metadata.relations,
								resource.metadata.relations ++ [resource.id])),
					},
					%{
						name: "#{resource.name} resource forked by #{owner.name}",
						note: params.description,
						repo: params.contribution_repository,
					}
				),
				{:ok, process_contribution} <-
					Process.Domain.create(%{name: "contribution of ${resource.name} by ${owner.name"}),
				{:ok, proposal} <-
					Proposal.Domain.create(%{name: process.name, note: params.description}),
				# Propose contribution
				{:ok, cite_resource_forked} <- Intent.Domain.create(%{
					action_id: "cite",
					input_of_id: process_contribution.id,
					provider_id: resource.primary_accountable_id,
					has_point_in_time: DateTime.utc_now(),
					resource_inventoried_as_id: forking_evt.resource_inventoried_as_id,
					resource_quantity: build_quantity(),
				}),
				{:ok, accept_resource_origin} <- Intent.Domain.create(%{
					action_id: "accept",
					input_of_id: process_contribution.id,
					receiver_id: owner.id,
					has_point_in_time: DateTime.utc_now(),
					resource_inventoried_as_id: resource.id,
					resource_quantity: build_quantity(),
				}),
				{:ok, modify_resource_origin} <- Intent.Domain.create(%{
					action_id: "modify",
					output_of_id: process_contribution.id,
					receiver_id: owner.id,
					has_point_in_time: DateTime.utc_now(),
					resource_inventoried_as_id: resource.id,
					resource_quantity: build_quantity(),
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
				:ok <- Wallet.add_idea_points(resource.primary_accountable_id, idea_points().on_fork),
				:ok <- Wallet.add_strength_points(params.owner_id, strength_points().on_fork) do
			{:ok, %{proposal: proposal, forking_evt: forking_evt}}
		end
	end)
end

@spec cite(Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, String.t() | Changeset.t()}
def cite(params) do
	Repo.multi(fn ->
		# TODO: we should check that the `process_id` exist somehow.
		with {:ok, resource} <- EconomicResource.Domain.one(params.resource_id),
				{:ok, evt} <- EconomicEvent.Domain.create(%{
					action_id: "cite",
					input_of_id: params.process_id,
					provider_id: params.owner_id,
					receiver_id: params.owner_id,
					has_point_in_time: DateTime.utc_now(),
					resource_inventoried_as_id: params.resource_id,
					resource_quantity: build_quantity(),
				}),
				# economic system: points assignments
				:ok <- Wallet.add_idea_points(params.owner_id, idea_points().on_cite),
				:ok <- Wallet.add_strength_points(resource.primary_accountable_id, strength_points().on_cite) do
			{:ok, evt}
		else
			:error -> {:error, "couldn't add points"}
			{:error, reason} -> {:error, reason}
		end
	end)
end

@spec approve(Schema.params())
	:: {:ok, EconomicEvent.t()} | {:error, Changeset.t()}
def approve(params) do
	Repo.multi(fn ->
		with {:ok, proposal} <- Proposal.Domain.one(params.proposal_id),
				proposal <- Repo.preload(proposal, :primary_intents) do
			{:ok, proposal}
		end
	end)
end
end
